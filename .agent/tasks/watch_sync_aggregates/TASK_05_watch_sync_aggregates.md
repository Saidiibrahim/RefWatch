---
task_id: 05
plan_id: PLAN_watch_sync_aggregates
plan_file: ../../plans/watch_sync_aggregates/PLAN_watch_sync_aggregates.md
title: Establish validation, testing, and diagnostics strategy
phase: Phase 5 - Quality & Observability
---

## Objective
Define how we will verify the new sync flows and provide diagnostics for failures without requiring live devices.

## Scope
- Enumerate unit, integration, and end-to-end tests needed on both iOS and watch targets, reusing existing WCSession mocks where possible, and covering manual sync entry points.
- Propose logging, analytics, or user-facing status indicators to trace sync progress and errors, including the Settings sync button feedback and connectivity banners, and capture schema version/ack failures.
- Plan manual QA scenarios covering offline behaviour, queued updates, delete propagation, and stale cache detection.

## Deliverables
- Testing matrix mapping scenarios to automated or manual coverage.
- Diagnostics checklist (OSLog categories, NotificationCenter hooks, debug UI updates).
- Risk assessment for remaining validation gaps, especially around payload version drift and chunked transfer failures.

## Progress
- Added `WatchAggregateSyncCoordinatorTests` covering chunk reassembly safeguards (stale payload drop) and acknowledgement pruning to keep the delta outbox and status in sync (`RefZoneWatchOSTests/WatchAggregateSyncCoordinatorTests.swift`).
- Expanded watch coordinator logging and status mutation to surface delta queue counts/failures through existing `.syncStatusUpdate` diagnostics.
- Documented outstanding test coverage needs (delta outbox retry bookkeeping, WCSession mock roundtrips) for follow-up in test matrix.
- Implemented targeted pipeline unit tests:
  - `WatchAggregateDeltaOutboxStoreTests` validates retry bookkeeping and persistence across store reinitialisation.
  - `IOSConnectivitySyncClientAggregateTests` exercises queueing while signed out, retry loops, and WCSession message/userInfo decoding paths.

## Test Matrix
- **Watch aggregate stores (automated)**
  - `WatchAggregateSyncCoordinatorTests` – chunk ordering + ack pruning regression coverage.
  - `WatchAggregateDeltaOutboxStoreTests.testMarkAttemptedUpdatesFailureCountAndTimestamp` – verifies failure counts and timestamps mutate correctly.
  - `WatchAggregateDeltaOutboxStoreTests.testPendingDeltasPersistAcrossStoreInitialization` – guards persistence across container re-spins.
- **iOS connectivity (automated)**
  - `IOSConnectivitySyncClientAggregateTests.testAggregateDeltaProcessesAfterSignIn` – queued delta drains after auth attach.
  - `IOSConnectivitySyncClientAggregateTests.testFailedDeltaIsRequeuedAndRetried` – ensures retry loop posts diagnostics and replays envelopes.
  - `IOSConnectivitySyncClientAggregateTests.testWCSessionMessageRoundtripQueuesDelta` / `.testWCSessionUserInfoRoundtripQueuesDelta` – decode paths for foreground/background transfers.
- **Manual QA (simulator or paired hardware)**
  - Trigger manual “Resync Library” from iOS Settings while toggling watch reachability; confirm status fields (`queuedDeltas`, `pendingSnapshotChunks`, timestamps) update.
  - Sign-out/sign-in flows on iOS to ensure queued deltas are discarded or flushed with appropriate banners.
  - Supabase pull sanity check once backend payloads are available (teams/venues/schedules should reflect watch edits after reconnect).

## Diagnostics Checklist
- Monitor `.syncStatusUpdate` payloads for the new keys (`queuedDeltas`, `pendingSnapshotChunks`, `lastSnapshot`) in both iOS `SyncDiagnosticsCenter` and watch Settings screens.
- Confirm `.syncFallbackOccurred` contexts (`ios.aggregate.delta.queued`, `.retry`, `.status.unreachable`) surface in OSLog when exercising automated tests.
- Ensure Ack store drains via `ConnectivitySyncController.externalAckProvider` when additional providers register (exercise via unit mocks before shipping).
