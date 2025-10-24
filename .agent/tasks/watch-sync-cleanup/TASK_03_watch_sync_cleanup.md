---
task_id: 03
plan_id: PLAN_watch_sync_cleanup
plan_file: ../../plans/watch-sync-cleanup/PLAN_watch_sync_cleanup.md
title: Send completed match payloads from iOS to watch
phase: Phase 3 - Completed Match Push
---

- Make `IOSConnectivitySyncClient` conform to `ConnectivitySyncProviding` and implement `sendCompletedMatch`.
- Inject the connectivity client into the iOS `MatchViewModel` so `finalizeMatch()` delivers completed match snapshots.
- Confirm payload delivery paths by running an instrumented match completion on iOS and observing WatchConnectivity traffic.
