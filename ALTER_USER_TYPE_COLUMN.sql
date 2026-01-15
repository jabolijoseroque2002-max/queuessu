-- Migration script to change student_type to user_type and add 'External' option

-- 1. Drop the old constraint first
ALTER TABLE queue_entries DROP CONSTRAINT IF EXISTS check_student_type;

-- 2. Rename the column from student_type to user_type
-- Using DO block to handle if column doesn't exist (e.g. if it was already renamed)
DO $$
BEGIN
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'queue_entries' AND column_name = 'student_type') THEN
    ALTER TABLE queue_entries RENAME COLUMN student_type TO user_type;
  END IF;
END $$;

-- 3. If user_type column doesn't exist (and student_type didn't exist), create it
ALTER TABLE queue_entries ADD COLUMN IF NOT EXISTS user_type VARCHAR(50) DEFAULT 'Student';

-- 4. Add the new constraint including 'External'
ALTER TABLE queue_entries DROP CONSTRAINT IF EXISTS check_user_type;

ALTER TABLE queue_entries 
ADD CONSTRAINT check_user_type 
CHECK (user_type IN ('Student', 'Graduated', 'External'));

-- 5. Update comment
COMMENT ON COLUMN queue_entries.user_type IS 'Indicates whether the person is a Student, Graduated, or External';

-- 6. Verify
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'queue_entries' 
AND column_name = 'user_type';
