-- Global Queue Numbering System Migration
-- This script adds batch_number tracking for reset cycles and enables global queue numbering

-- Step 1: Add batch_number column to queue_entries table
DO $$
BEGIN
    -- Add batch_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'batch_number'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN batch_number integer NOT NULL DEFAULT 1;
        
        -- Create index for batch_number for efficient queries
        CREATE INDEX IF NOT EXISTS idx_queue_entries_batch_number 
            ON public.queue_entries USING btree (batch_number) TABLESPACE pg_default;
        
        -- Create composite index for serving order (batch_number ASC, queue_number ASC)
        CREATE INDEX IF NOT EXISTS idx_queue_entries_batch_queue 
            ON public.queue_entries USING btree (batch_number ASC, queue_number ASC) TABLESPACE pg_default;
        
        -- Create composite index for department queries with batch priority
        CREATE INDEX IF NOT EXISTS idx_queue_dept_batch_queue 
            ON public.queue_entries USING btree (department, batch_number ASC, queue_number ASC, status) TABLESPACE pg_default;
        
        RAISE NOTICE 'Added batch_number column to queue_entries table';
    ELSE
        RAISE NOTICE 'batch_number column already exists';
    END IF;
END $$;

-- Step 2: Create queue_batch_settings table to track current batch number
CREATE TABLE IF NOT EXISTS public.queue_batch_settings (
    id text NOT NULL DEFAULT 'global'::text,
    current_batch_number integer NOT NULL DEFAULT 1,
    last_reset_at timestamp with time zone NOT NULL DEFAULT now(),
    reset_reason text,
    CONSTRAINT queue_batch_settings_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Initialize the settings table with default values if it doesn't exist
INSERT INTO public.queue_batch_settings (id, current_batch_number, last_reset_at, reset_reason)
VALUES ('global', 1, now(), 'Initial setup')
ON CONFLICT (id) DO NOTHING;

-- Step 3: Create function to get next global queue number
CREATE OR REPLACE FUNCTION get_next_global_queue_number()
RETURNS integer AS $$
DECLARE
    next_number integer;
BEGIN
    -- Get the maximum queue number across ALL departments in the current batch
    SELECT COALESCE(MAX(queue_number), 0) + 1 INTO next_number
    FROM queue_entries
    WHERE batch_number = (SELECT current_batch_number FROM queue_batch_settings WHERE id = 'global');
    
    RETURN next_number;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create function to increment batch number (for reset)
CREATE OR REPLACE FUNCTION increment_batch_number(reset_reason text DEFAULT 'Manual reset')
RETURNS integer AS $$
DECLARE
    new_batch_number integer;
BEGIN
    -- Get current batch number and increment
    SELECT current_batch_number + 1 INTO new_batch_number
    FROM queue_batch_settings
    WHERE id = 'global';
    
    -- Update the settings
    UPDATE queue_batch_settings
    SET current_batch_number = new_batch_number,
        last_reset_at = now(),
        reset_reason = increment_batch_number.reset_reason
    WHERE id = 'global';
    
    RETURN new_batch_number;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create function to get current batch number
CREATE OR REPLACE FUNCTION get_current_batch_number()
RETURNS integer AS $$
DECLARE
    batch_num integer;
BEGIN
    SELECT current_batch_number INTO batch_num
    FROM queue_batch_settings
    WHERE id = 'global';
    
    RETURN COALESCE(batch_num, 1);
END;
$$ LANGUAGE plpgsql;

-- Step 6: Update existing entries to have batch_number = 1 (if they don't have it)
UPDATE public.queue_entries 
SET batch_number = 1 
WHERE batch_number IS NULL OR batch_number = 0;

-- Step 7: Ensure batch_number is NOT NULL
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' 
        AND column_name = 'batch_number' 
        AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.queue_entries ALTER COLUMN batch_number SET NOT NULL;
    END IF;
END $$;

-- Grant permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE ON queue_batch_settings TO your_app_user;
-- GRANT EXECUTE ON FUNCTION get_next_global_queue_number TO your_app_user;
-- GRANT EXECUTE ON FUNCTION increment_batch_number TO your_app_user;
-- GRANT EXECUTE ON FUNCTION get_current_batch_number TO your_app_user;

DO $$
BEGIN
    RAISE NOTICE 'Global queue numbering migration completed successfully';
    RAISE NOTICE 'Current batch number: %', get_current_batch_number();
END $$;


