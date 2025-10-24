---
task_id: 02
plan_id: PLAN_watch_sync_cleanup
plan_file: ../../plans/watch-sync-cleanup/PLAN_watch_sync_cleanup.md
title: Ensure iOS schedules appear in watch SavedMatchesListView
phase: Phase 2 - Schedule Sync Fixes
---

- Apply code changes so iOS schedule saves immediately enqueue snapshot updates and the watch merges them into `MatchViewModel.savedMatches`.
- Adjust filtering logic in `MatchViewModel.updateLibrary` or related helpers if remote schedules are being dropped.
- Verify on device or simulator that a newly created schedule surfaces in `SavedMatchesListView`.
