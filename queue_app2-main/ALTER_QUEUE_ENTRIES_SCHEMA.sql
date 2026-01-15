-- ALTER Queue Entries Schema
-- This script:
-- 1. Adds "Others" purpose to purposes table
-- 2. Renames student_type to user_type
-- 3. Adds "External" as a valid user type
-- 4. Updates constraints and existing data

-- Step 1: Add "Others" purpose if it doesn't exist
INSERT INTO public.purposes (name, description, is_active)
VALUES ('Others', 'Other purposes not listed', true)
ON CONFLICT (name) DO UPDATE
SET is_active = true,
    description = 'Other purposes not listed';

-- Step 2: Rename student_type column to user_type
DO $$
BEGIN
    -- Check if column exists and rename if needed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'student_type'
    ) THEN
        -- Rename the column
        ALTER TABLE public.queue_entries 
        RENAME COLUMN student_type TO user_type;
        
        RAISE NOTICE 'Renamed student_type column to user_type';
    ELSE
        -- If user_type doesn't exist, add it
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'queue_entries' AND column_name = 'user_type'
        ) THEN
            ALTER TABLE public.queue_entries 
            ADD COLUMN user_type character varying(50) NULL DEFAULT 'Student'::character varying;
            
            RAISE NOTICE 'Added user_type column';
        END IF;
    END IF;
END $$;

-- Step 3: Update existing data - set default to 'Student' if NULL
UPDATE public.queue_entries 
SET user_type = 'Student' 
WHERE user_type IS NULL;

-- Step 4: Drop old check constraint if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_student_type'
    ) THEN
        ALTER TABLE public.queue_entries 
        DROP CONSTRAINT check_student_type;
        
        RAISE NOTICE 'Dropped old check_student_type constraint';
    END IF;
END $$;

-- Step 5: Add new check constraint for user_type with Student, Graduated, and External
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_user_type'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD CONSTRAINT check_user_type CHECK (
            (user_type)::text = ANY (
                (ARRAY[
                    'Student'::character varying,
                    'Graduated'::character varying,
                    'External'::character varying
                ])::text[]
            )
        );
        
        RAISE NOTICE 'Added check_user_type constraint with Student, Graduated, and External';
    END IF;
END $$;

-- Step 6: Ensure user_type is NOT NULL with default
DO $$
BEGIN
    -- Set default value for user_type
    ALTER TABLE public.queue_entries 
    ALTER COLUMN user_type SET DEFAULT 'Student'::character varying;
    
    -- Make it NOT NULL if it's currently nullable
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' 
        AND column_name = 'user_type' 
        AND is_nullable = 'YES'
    ) THEN
        -- Update any NULL values first
        UPDATE public.queue_entries 
        SET user_type = 'Student' 
        WHERE user_type IS NULL;
        
        -- Then make it NOT NULL
        ALTER TABLE public.queue_entries 
        ALTER COLUMN user_type SET NOT NULL;
        
        RAISE NOTICE 'Set user_type to NOT NULL with default Student';
    END IF;
END $$;

-- Step 7: Update the trigger function comment (if needed)
-- The trigger function doesn't need changes, but we can add a comment
COMMENT ON COLUMN public.queue_entries.user_type IS 
    'User type: Student, Graduated, or External';

-- Step 8: Verify the changes
DO $$
DECLARE
    purpose_count integer;
    user_type_count integer;
BEGIN
    -- Check if Others purpose exists
    SELECT COUNT(*) INTO purpose_count
    FROM public.purposes
    WHERE name = 'Others' AND is_active = true;
    
    IF purpose_count > 0 THEN
        RAISE NOTICE '✅ Others purpose exists and is active';
    ELSE
        RAISE WARNING '⚠️ Others purpose not found or inactive';
    END IF;
    
    -- Check if user_type column exists
    SELECT COUNT(*) INTO user_type_count
    FROM information_schema.columns
    WHERE table_name = 'queue_entries' AND column_name = 'user_type';
    
    IF user_type_count > 0 THEN
        RAISE NOTICE '✅ user_type column exists';
    ELSE
        RAISE WARNING '⚠️ user_type column not found';
    END IF;
    
    RAISE NOTICE '✅ Schema alterations completed successfully';
END $$;


