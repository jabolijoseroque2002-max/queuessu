# Fixing PostgREST Schema Cache Error

## Error Message
```
PostgrestException(message: Could not find the 'student_type' column of 'queue_entries' in the schema cache, code: PGRST204)
```

## Cause
PostgREST (Supabase's API layer) caches the database schema. After renaming `student_type` to `user_type`, PostgREST's cache still expects the old column name.

## Solutions

### Option 1: Refresh PostgREST Schema Cache (Recommended)
1. Go to your Supabase Dashboard
2. Navigate to **Settings** → **API**
3. Click **"Reload Schema"** or **"Refresh Schema Cache"**
4. Wait a few seconds for the cache to refresh

### Option 2: Restart PostgREST Service
1. Go to Supabase Dashboard
2. Navigate to **Settings** → **Database**
3. Look for **"Restart Services"** or contact Supabase support to restart PostgREST

### Option 3: Wait for Automatic Refresh
PostgREST's schema cache refreshes automatically, but it may take a few minutes. Wait 5-10 minutes and try again.

### Option 4: Verify Database Schema
Run this SQL query in Supabase SQL Editor to verify the column exists:

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'queue_entries' 
AND column_name IN ('user_type', 'student_type');
```

You should see `user_type` but NOT `student_type`.

## Verification
After refreshing the cache, the error should be resolved. The code is already updated to use `user_type` correctly.

## Note
The Flutter code has been updated to use `user_type` instead of `student_type`. Make sure you:
1. Run `flutter clean` (already done)
2. Restart your Flutter app
3. Refresh PostgREST schema cache in Supabase


