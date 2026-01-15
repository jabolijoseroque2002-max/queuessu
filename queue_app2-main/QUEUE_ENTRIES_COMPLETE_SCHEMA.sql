-- Complete Queue Entries Table Schema
-- This script creates or updates the queue_entries table with all required columns, indexes, constraints, and triggers

-- Step 1: Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_priority ON public.queue_entries;

-- Step 2: Create or replace the update_priority_status function
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (COALESCE(NEW.is_pwd, FALSE) OR COALESCE(NEW.is_senior, FALSE) OR COALESCE(NEW.is_pregnant, FALSE));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create the queue_entries table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.queue_entries (
    id text NOT NULL,
    name text NOT NULL,
    ssu_id text NOT NULL,
    email text NOT NULL,
    phone_number text NOT NULL,
    department text NOT NULL,
    purpose text NOT NULL,
    timestamp timestamp with time zone NOT NULL DEFAULT now(),
    queue_number integer NOT NULL,
    status text NOT NULL DEFAULT 'waiting'::text,
    countdown_start timestamp with time zone NULL,
    countdown_duration integer NOT NULL DEFAULT 30,
    sms_opt_in boolean NOT NULL DEFAULT false,
    notified_top5 boolean NOT NULL DEFAULT false,
    last_notified_at timestamp with time zone NULL,
    is_pwd boolean NULL DEFAULT false,
    is_senior boolean NULL DEFAULT false,
    is_priority boolean NULL DEFAULT false,
    user_type character varying(50) NULL DEFAULT 'Student'::character varying,
    reference_number character varying(50) NULL,
    course character varying(20) NOT NULL,
    is_pregnant boolean NOT NULL DEFAULT false,
    gender text NULL,
    graduation_year integer NULL,
    age integer NULL,
    batch_number integer NOT NULL DEFAULT 1,
    CONSTRAINT queue_entries_pkey PRIMARY KEY (id),
    CONSTRAINT queue_entries_reference_number_key UNIQUE (reference_number),
    CONSTRAINT fk_queue_entries_department FOREIGN KEY (department) REFERENCES departments (code),
    CONSTRAINT fk_queue_entries_purpose FOREIGN KEY (purpose) REFERENCES purposes (name),
    CONSTRAINT check_user_type CHECK (
        (
            (user_type)::text = ANY (
                (
                    ARRAY[
                        'Student'::character varying,
                        'Graduated'::character varying,
                        'External'::character varying
                    ]
                )::text[]
            )
        )
    )
) TABLESPACE pg_default;

-- Step 4: Add missing columns if table already exists
DO $$
BEGIN
    -- Add batch_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'batch_number'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN batch_number integer NOT NULL DEFAULT 1;
        RAISE NOTICE 'Added batch_number column';
    END IF;

    -- Add gender column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'gender'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN gender text NULL;
        RAISE NOTICE 'Added gender column';
    END IF;

    -- Add graduation_year column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'graduation_year'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN graduation_year integer NULL;
        RAISE NOTICE 'Added graduation_year column';
    END IF;

    -- Add age column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'age'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN age integer NULL;
        RAISE NOTICE 'Added age column';
    END IF;

    -- Ensure batch_number is NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' 
        AND column_name = 'batch_number' 
        AND is_nullable = 'YES'
    ) THEN
        UPDATE public.queue_entries SET batch_number = 1 WHERE batch_number IS NULL;
        ALTER TABLE public.queue_entries ALTER COLUMN batch_number SET NOT NULL;
        ALTER TABLE public.queue_entries ALTER COLUMN batch_number SET DEFAULT 1;
        RAISE NOTICE 'Set batch_number to NOT NULL with default 1';
    END IF;

    -- Ensure course is NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' 
        AND column_name = 'course' 
        AND is_nullable = 'YES'
    ) THEN
        UPDATE public.queue_entries SET course = 'N/A' WHERE course IS NULL;
        ALTER TABLE public.queue_entries ALTER COLUMN course SET NOT NULL;
        RAISE NOTICE 'Set course to NOT NULL';
    END IF;

    -- Ensure is_pregnant is NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' 
        AND column_name = 'is_pregnant' 
        AND is_nullable = 'YES'
    ) THEN
        UPDATE public.queue_entries SET is_pregnant = false WHERE is_pregnant IS NULL;
        ALTER TABLE public.queue_entries ALTER COLUMN is_pregnant SET NOT NULL;
        ALTER TABLE public.queue_entries ALTER COLUMN is_pregnant SET DEFAULT false;
        RAISE NOTICE 'Set is_pregnant to NOT NULL with default false';
    END IF;
END $$;

-- Step 5: Create all indexes
CREATE INDEX IF NOT EXISTS idx_queue_entries_countdown_start 
    ON public.queue_entries USING btree (countdown_start) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_status_queue 
    ON public.queue_entries USING btree (department, status, queue_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_status_timestamp 
    ON public.queue_entries USING btree (department, status, timestamp DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_department 
    ON public.queue_entries USING btree (department) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_status 
    ON public.queue_entries USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_queue_number 
    ON public.queue_entries USING btree (queue_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_queue_desc 
    ON public.queue_entries USING btree (department, queue_number DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_status_waiting 
    ON public.queue_entries USING btree (department, status, queue_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_reference_number 
    ON public.queue_entries USING btree (reference_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_course 
    ON public.queue_entries USING btree (course) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_department_course 
    ON public.queue_entries USING btree (department, course) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_graduation_year 
    ON public.queue_entries USING btree (graduation_year) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_gender 
    ON public.queue_entries USING btree (gender) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_batch_number 
    ON public.queue_entries USING btree (batch_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_batch_queue 
    ON public.queue_entries USING btree (batch_number, queue_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_priority_display 
    ON public.queue_entries USING btree (
        department,
        is_priority DESC,
        queue_number,
        status
    ) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_batch_queue 
    ON public.queue_entries USING btree (department, batch_number, queue_number, status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_is_pregnant 
    ON public.queue_entries USING btree (is_pregnant) TABLESPACE pg_default;

-- Step 6: Add constraints if they don't exist
DO $$
BEGIN
    -- Add primary key constraint if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'queue_entries_pkey'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD CONSTRAINT queue_entries_pkey PRIMARY KEY (id);
        RAISE NOTICE 'Added primary key constraint';
    END IF;

    -- Add unique constraint on reference_number if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'queue_entries_reference_number_key'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD CONSTRAINT queue_entries_reference_number_key UNIQUE (reference_number);
        RAISE NOTICE 'Added unique constraint on reference_number';
    END IF;

    -- Add foreign key to departments table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_queue_entries_department'
    ) THEN
        ALTER TABLE public.queue_entries
        ADD CONSTRAINT fk_queue_entries_department 
        FOREIGN KEY (department) REFERENCES departments(code);
        RAISE NOTICE 'Added foreign key constraint to departments';
    END IF;

    -- Add foreign key to purposes table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_queue_entries_purpose'
    ) THEN
        ALTER TABLE public.queue_entries
        ADD CONSTRAINT fk_queue_entries_purpose 
        FOREIGN KEY (purpose) REFERENCES purposes(name);
        RAISE NOTICE 'Added foreign key constraint to purposes';
    END IF;

    -- Rename student_type to user_type if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'student_type'
    ) THEN
        ALTER TABLE public.queue_entries 
        RENAME COLUMN student_type TO user_type;
        RAISE NOTICE 'Renamed student_type column to user_type';
    END IF;

    -- Add user_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'user_type'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN user_type character varying(50) NULL DEFAULT 'Student'::character varying;
        RAISE NOTICE 'Added user_type column';
    END IF;

    -- Drop old check constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_student_type'
    ) THEN
        ALTER TABLE public.queue_entries 
        DROP CONSTRAINT check_student_type;
        RAISE NOTICE 'Dropped old check_student_type constraint';
    END IF;

    -- Add check constraint on user_type if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_user_type'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD CONSTRAINT check_user_type CHECK (
            (user_type)::text = ANY (
                (ARRAY['Student'::character varying, 'Graduated'::character varying, 'External'::character varying])::text[]
            )
        );
        RAISE NOTICE 'Added check constraint on user_type with Student, Graduated, and External';
    END IF;

    -- Update existing NULL values
    UPDATE public.queue_entries 
    SET user_type = 'Student' 
    WHERE user_type IS NULL;
END $$;

-- Step 7: Create trigger for updating priority status
CREATE TRIGGER trigger_update_priority
    BEFORE INSERT OR UPDATE ON public.queue_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_priority_status();

-- Step 8: Update existing records to set is_priority based on flags
UPDATE public.queue_entries 
SET is_priority = (COALESCE(is_pwd, FALSE) OR COALESCE(is_senior, FALSE) OR COALESCE(is_pregnant, FALSE))
WHERE is_priority IS NULL OR is_priority != (COALESCE(is_pwd, FALSE) OR COALESCE(is_senior, FALSE) OR COALESCE(is_pregnant, FALSE));

-- Step 9: Create queue_batch_settings table for global queue numbering
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

-- Step 10: Create helper functions for global queue numbering
CREATE OR REPLACE FUNCTION get_next_global_queue_number()
RETURNS integer AS $$
DECLARE
    next_number integer;
    current_batch integer;
BEGIN
    -- Get current batch number
    SELECT current_batch_number INTO current_batch
    FROM queue_batch_settings
    WHERE id = 'global';
    
    -- Get the maximum queue number across ALL departments in the current batch
    SELECT COALESCE(MAX(queue_number), 0) + 1 INTO next_number
    FROM queue_entries
    WHERE batch_number = COALESCE(current_batch, 1);
    
    RETURN next_number;
END;
$$ LANGUAGE plpgsql;

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

-- Step 11: Grant permissions (adjust as needed for your setup)
-- Uncomment and modify these lines based on your database user setup
-- GRANT SELECT, INSERT, UPDATE ON queue_entries TO your_app_user;
-- GRANT SELECT, INSERT, UPDATE ON queue_batch_settings TO your_app_user;
-- GRANT EXECUTE ON FUNCTION get_next_global_queue_number TO your_app_user;
-- GRANT EXECUTE ON FUNCTION increment_batch_number TO your_app_user;
-- GRANT EXECUTE ON FUNCTION get_current_batch_number TO your_app_user;

-- Step 12: Final summary
DO $$
BEGIN
    RAISE NOTICE '✅ Queue entries table schema updated successfully';
    RAISE NOTICE '✅ Batch numbering system initialized';
    RAISE NOTICE '✅ All indexes created';
    RAISE NOTICE '✅ All constraints applied';
    RAISE NOTICE '✅ Trigger created for priority status updates';
    RAISE NOTICE 'Current batch number: %', get_current_batch_number();
END $$;

