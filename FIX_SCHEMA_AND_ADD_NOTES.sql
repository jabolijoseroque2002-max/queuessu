-- Add notes column if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'notes'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN notes text;
    END IF;
END $$;

-- Add 'Others' to purposes table if not exists
-- Assuming purposes table has 'name' column as primary key or unique
INSERT INTO public.purposes (name)
SELECT 'Others'
WHERE NOT EXISTS (
    SELECT 1 FROM public.purposes WHERE name = 'Others'
);

-- Ensure user_type column exists (rename student_type if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'student_type'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'user_type'
    ) THEN
        ALTER TABLE public.queue_entries RENAME COLUMN student_type TO user_type;
    END IF;
END $$;
