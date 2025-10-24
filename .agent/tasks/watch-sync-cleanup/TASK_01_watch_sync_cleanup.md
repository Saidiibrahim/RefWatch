---
task_id: 01
plan_id: PLAN_watch_sync_cleanup
plan_file: ../../plans/watch-sync-cleanup/PLAN_watch_sync_cleanup.md
title: Trace schedule sync pipeline from iOS creation to watch saved matches
phase: Phase 1 - Diagnostics
---

Document the current behavior:

- Instrument `RefZoneiOS/Core/Platform/Connectivity/AggregateSyncCoordinator.swift` to confirm new schedules trigger snapshot builds and flushes.
- Capture the payload received in `RefZoneWatchOS/Core/Platform/Connectivity/WatchConnectivitySyncClient.swift` and verify schedules land in `WatchAggregateLibraryStore`.
- Summarize findings and highlight any missing hops in the ExecPlan’s surprises section.
