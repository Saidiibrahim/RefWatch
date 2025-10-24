---
task_id: 00
plan_id: PLAN_watch_sync_status_cleanup
plan_file: ../../plans/watch_sync_status_cleanup/PLAN_watch_sync_status_cleanup.md
title: Fix status enum decoder to handle database snake_case format
phase: Pre-Phase 0 - Foundation Fix
priority: CRITICAL - Blocks all other tasks
---

## Objective
Fix the status enum decoder to correctly map database values (`in_progress`, `completed`, `canceled`) to Swift enum cases (`.inProgress`, `.completed`, `.canceled`) before implementing any filtering logic in subsequent tasks.

## Background
The Supabase database stores match status using snake_case enum values (`scheduled`, `in_progress`, `completed`, `canceled`), but the Swift `ScheduledMatch.Status` enum uses camelCase rawValues. Current code throughout the codebase relies on `Status(rawValue:)` which returns `nil` for `"in_progress"`, causing silent fallback to `.scheduled`.

**Evidence from production database**:
```sql
SELECT status FROM scheduled_matches LIMIT 3;
-- Returns: "scheduled", "scheduled", "scheduled"
-- (in_progress matches incorrectly appear as scheduled)
```

**Impact**: Without this fix, TASK_01's filtering logic will incorrectly treat all in-progress matches as scheduled, and TASK_02's schedule status updates will perpetuate the incorrect mapping.

## Scope
- Add custom decoder extension `ScheduledMatch.Status.init(fromDatabase:)` that explicitly maps snake_case database values to Swift enum cases
- Update `SwiftDataScheduleStore` aggregate sync code (line 171) to use new decoder instead of `Status(rawValue:)`
- Update `ScheduledMatchRecord.status` computed property (line 74) to use new decoder for defensive consistency
- Add unit tests proving all four database status values decode correctly
- Add debug telemetry for unknown status values to catch future schema changes

## Deliverables

### Code Changes
1. **ScheduledMatch.swift** - Add decoder extension:
   ```swift
   extension ScheduledMatch.Status {
       /// Decode status from database snake_case format
       /// Database uses: scheduled, in_progress, completed, canceled
       /// Swift enum uses: scheduled, inProgress, completed, canceled
       init(fromDatabase raw: String) {
           switch raw {
           case "scheduled": self = .scheduled
           case "in_progress": self = .inProgress
           case "completed": self = .completed
           case "canceled": self = .canceled
           default:
               #if DEBUG
               print("⚠️ Unknown schedule status: '\(raw)', defaulting to .scheduled")
               #endif
               self = .scheduled
           }
       }
   }
   ```

2. **SwiftDataScheduleStore.swift** (line 171) - Replace:
   ```swift
   status: ScheduledMatch.Status(rawValue: aggregate.statusRaw) ?? .scheduled,
   ```
   With:
   ```swift
   status: ScheduledMatch.Status(fromDatabase: aggregate.statusRaw),
   ```

3. **ScheduledMatchRecord.swift** (line 74) - Update computed property:
   ```swift
   var status: ScheduledMatch.Status {
       get { ScheduledMatch.Status(fromDatabase: statusRaw) }
       set { statusRaw = newValue.rawValue }
   }
   ```

### Test Coverage
4. **ScheduledMatchStatusDecoderTests.swift** (new file in RefZoneiOSTests):
   ```swift
   func test_statusDecoding_mapsSnakeCaseToCamelCase() {
       #expect(ScheduledMatch.Status(fromDatabase: "in_progress") == .inProgress)
       #expect(ScheduledMatch.Status(fromDatabase: "scheduled") == .scheduled)
       #expect(ScheduledMatch.Status(fromDatabase: "completed") == .completed)
       #expect(ScheduledMatch.Status(fromDatabase: "canceled") == .canceled)
   }

   func test_statusDecoding_fallsBackToScheduledForUnknown() {
       #expect(ScheduledMatch.Status(fromDatabase: "unknown_status") == .scheduled)
       #expect(ScheduledMatch.Status(fromDatabase: "") == .scheduled)
   }
   ```

### Documentation
5. Update PLAN decision log with decoder fix rationale

## Acceptance Criteria
- ✓ `ScheduledMatch.Status(fromDatabase: "in_progress")` returns `.inProgress`
- ✓ `ScheduledMatch.Status(fromDatabase: "scheduled")` returns `.scheduled`
- ✓ `ScheduledMatch.Status(fromDatabase: "completed")` returns `.completed`
- ✓ `ScheduledMatch.Status(fromDatabase: "canceled")` returns `.canceled`
- ✓ Unknown values default to `.scheduled` with debug telemetry
- ✓ All existing tests pass without modification
- ✓ SwiftDataScheduleStore uses new decoder consistently
- ✓ ScheduledMatchRecord status getter uses new decoder

## Dependencies
**Blocks**: TASK_01, TASK_02 (filtering logic depends on correct status decoding)

## Estimated Effort
- Code changes: 30 minutes
- Test implementation: 1 hour
- **Total**: 1.5 hours
