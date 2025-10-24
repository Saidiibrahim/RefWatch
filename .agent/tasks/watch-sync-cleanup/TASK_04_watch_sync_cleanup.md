---
task_id: 04
plan_id: PLAN_watch_sync_cleanup
plan_file: ../../plans/watch-sync-cleanup/PLAN_watch_sync_cleanup.md
title: Persist iOS-completed matches on watch and refresh history UI
phase: Phase 4 - Completed Match Ingestion
---

- Teach `WatchConnectivitySyncClient` to decode `"completedMatch"` payloads and save them through `MatchHistoryService`.
- Update any schedule state linked to the completed match and trigger UI reloads in `MatchHistoryView`.
- Validate on device that finishing a match on iOS afterwards surfaces in the watch history list post-sync.
