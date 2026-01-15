# Global Queue Numbering System Implementation

## Overview
This implementation updates the queue system to use **global continuous queue numbering** across all departments, with **batch/reset cycle tracking** for proper priority handling.

## Key Features

### 1. Global Continuous Queue Numbering
- Queue numbers are now **continuous across all departments**
- Example: CIT student → Queue 01, CAS student → Queue 02, Next department → Queue 03
- No more per-department numbering

### 2. Batch/Reset Cycle Tracking
- Each queue entry has a `batch_number` field that tracks which reset cycle it belongs to
- When a reset/cut-off is triggered, the batch number increments
- Existing entries keep their original batch numbers and queue numbers

### 3. Cut-Off / Reset Function
- **Does NOT delete entries** - all records are preserved permanently
- Increments the batch number for new entries
- Next queue number resets to 01 for new entries after reset
- Existing entries remain unchanged

### 4. Priority Handling
- **Older batches have priority over newer batches**
- Example: Queue 25 (batch 1) is served before Queue 01 (batch 2)
- Within the same batch:
  - Priority users (PWD/Senior/Pregnant) are served first
  - Then by queue number (lower numbers first)

### 5. Serving Order
The system serves entries in this order:
1. **Batch number** (ascending - older batches first)
2. **Priority status** (PWD/Senior/Pregnant first)
3. **Queue number** (ascending - lower numbers first)
4. **Status** (serving before waiting)

## Database Changes

### New Column
- `queue_entries.batch_number` (integer, NOT NULL, default: 1)
  - Tracks which reset cycle the entry belongs to

### New Table
- `queue_batch_settings`
  - `id` (text, primary key, default: 'global')
  - `current_batch_number` (integer, default: 1)
  - `last_reset_at` (timestamp)
  - `reset_reason` (text)

### New Database Functions
- `get_next_global_queue_number()` - Returns next global queue number
- `increment_batch_number(reset_reason)` - Increments batch number for reset
- `get_current_batch_number()` - Returns current batch number

## Code Changes

### Model Updates
- `QueueEntry` model now includes `batchNumber` field
- Default batch number is 1 for backward compatibility

### Service Updates
- `_getNextQueueNumberForDepartment()` → `_getNextGlobalQueueNumber()`
  - Now gets next number globally, not per department
- `resetQueue()` - Now increments batch number instead of deleting entries
- All query methods updated to sort by:
  1. `batch_number` ASC (older batches first)
  2. `is_priority` DESC (priority users first)
  3. `queue_number` ASC (lower numbers first)

### UI Updates
- Reset button label changed to "Cut-Off / Reset"
- Success message explains that entries are preserved
- All sorting logic updated to use batch-based priority

## Migration Steps

1. **Run the SQL migration script:**
   ```sql
   -- Execute: GLOBAL_QUEUE_NUMBERING_MIGRATION.sql
   ```

2. **Update existing entries:**
   - All existing entries will be set to `batch_number = 1`
   - This happens automatically in the migration script

3. **Deploy the updated code:**
   - The Flutter app will automatically use the new global numbering system
   - No data migration needed for existing entries

## Usage Examples

### Creating a Queue Entry
```dart
final entry = await supabaseService.addQueueEntry(
  name: 'John Doe',
  ssuId: '2024-00123',
  email: 'john@example.com',
  phoneNumber: '09123456789',
  department: 'CIT',
  purpose: 'Enrollment',
  course: 'BSIT',
);
// Entry gets next global queue number (e.g., 15 if last was 14)
// Entry gets current batch number (e.g., 1)
```

### Resetting/Cut-Off
```dart
await supabaseService.resetQueue();
// Batch number increments (e.g., 1 → 2)
// Next new entry will be queue 01 in batch 2
// Existing entries (batch 1) remain unchanged
```

### Serving Order Example
```
Batch 1:
  - Queue 25 (Priority) → Served first
  - Queue 26 (Regular) → Served second
  
Batch 2:
  - Queue 01 (Priority) → Served third (after all Batch 1 entries)
  - Queue 02 (Regular) → Served fourth
```

## Benefits

1. **Continuous Numbering**: Easy to track total queue entries across all departments
2. **Data Preservation**: No data loss during resets
3. **Proper Priority**: Older entries always served before newer entries
4. **Audit Trail**: Complete history maintained with batch tracking
5. **Flexibility**: Multiple resets supported while maintaining correct priority

## Testing Checklist

- [ ] Create entries across multiple departments - verify continuous numbering
- [ ] Trigger reset - verify batch number increments
- [ ] Create new entry after reset - verify starts at queue 01
- [ ] Verify older batch entries served before newer batch entries
- [ ] Verify priority users served first within same batch
- [ ] Verify lower queue numbers served first within same batch and priority level
- [ ] Verify all existing entries remain unchanged after reset
- [ ] Check database - verify batch_number column exists and populated

## Notes

- The system maintains backward compatibility - existing entries without batch_number default to 1
- All queue queries now include batch-based sorting
- The reset function no longer deletes data - it only increments the batch counter
- Queue history is permanently maintained for reporting and auditing


