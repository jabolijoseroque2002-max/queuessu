# User Type Implementation - Student, Graduated, or External

## ✅ **Changes Overview**

The previous "Student Type" feature has been refactored to "User Type" to support external users.

### 1. **Database Schema** ✅
- Renamed `student_type` column to `user_type` in `queue_entries` table.
- Updated constraint to allow: `'Student'`, `'Graduated'`, or `'External'`.
- Default value remains `'Student'`.

### 2. **QueueEntry Model** ✅
- Renamed `studentType` field to `userType`.
- JSON serialization uses `user_type` key (with backward compatibility fallback to `student_type`).
- Added support for "External" type.

### 3. **Information Form** ✅
- Renamed "Student Type" dropdown to "User Type".
- Added "External" option with icon.
- "External" users do not need to provide graduation year (same as "Student").

### 4. **Excel Export** ✅
- Renamed "Student Type" column to "User Type".
- Exports the new values correctly.

### 5. **Print Ticket** ✅
- Renamed "Student Type" label to "Type".
- Displays "External" if selected.

### 6. **Records View** ✅
- Updated to display `userType`.

## 📋 **SQL Script**

**File**: `ALTER_USER_TYPE_COLUMN.sql`

This script:
1. Renames the column `student_type` to `user_type`.
2. Updates the check constraint to include 'External'.
3. Preserves existing data.

### How to Apply:

1. Go to your Supabase project dashboard.
2. Navigate to SQL Editor.
3. Run the contents of `ALTER_USER_TYPE_COLUMN.sql`.

## 🎨 **UI Changes**

### Information Form
**Dropdown Options**:
- 👤 Student
- 🎓 Graduated
- 👤 External (New)

## 🔧 **Files Modified**

1. `lib/models/queue_entry.dart`
2. `lib/services/supabase_service.dart`
3. `lib/screens/information_form_screen.dart`
4. `lib/services/excel_export_service.dart`
5. `lib/services/print_service.dart`
6. `lib/screens/records_view_screen.dart`
7. `ALTER_USER_TYPE_COLUMN.sql` (New)

## ⚠️ **Backward Compatibility**

- The `QueueEntry.fromJson` method supports both `user_type` and `student_type` keys to prevent crashes if the API returns old data or during the migration window.
- However, the database migration is required for full functionality (especially for saving "External" type).
