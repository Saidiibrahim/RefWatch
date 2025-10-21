---
task_id: 04
plan_id: PLAN_watch_sync_aggregates
plan_file: ../../plans/watch_sync_aggregates/PLAN_watch_sync_aggregates.md
title: Plan iOS connectivity controller changes and backfill behaviour
phase: Phase 4 - iOS Pipeline Design
---

## Objective
Lay out the modifications required on iOS to package outbound aggregate updates, manage retries, and serve initial hydration payloads when a watch pairs or reconnects.

## Scope
- Identify triggers (Combine publishers from repositories/stores, background fetch) that signal data changes, including the manual Settings sync button path.
- Describe backlog/queue requirements mirroring the match sync approach, including persistence across app launches and connectivity status updates surfaced to the UI.
- Specify backfill logic for first run after sign-in or when the watch requests resync, ensuring Supabase remains authoritative.

## Deliverables
- Step-by-step outline of controller/service changes with file references (`ConnectivitySyncController`, `IOSConnectivitySyncClient`, new helpers) plus Settings sync button wiring and Combine subscription map.
- Retry/backoff and queue management plan.
- Notes on how to guard operations for signed-out state and handle multi-device scenarios.

## Progress
- Implemented `AggregateDeltaCoordinator` and `AggregateDeltaAckStore` to decode watch deltas, drive Supabase repositories, and collect acknowledgement IDs echoed by `AggregateSnapshotBuilder` (`RefZoneiOS/Core/Platform/Connectivity/AggregateDeltaCoordinator.swift`, `AggregateDeltaAckStore.swift`, `AggregateDeltaApplying.swift`).
- Extended `IOSConnectivitySyncClient` to queue aggregate deltas while signed out/unavailable, replay them serially once `AggregateDeltaHandling` is attached, and surface fallback diagnostics (`IOSConnectivitySyncClient.swift`).
- Updated `ConnectivitySyncController` to compose the new coordinator, attach it to `IOSConnectivitySyncClient`, and merge ack IDs from the coordinator with external providers (`ConnectivitySyncController.swift`).
- Added Supabase repository extensions and SwiftData store helpers to upsert/delete teams, competitions, venues, and schedules when deltas arrive while ensuring pending push/deletion bookkeeping stays accurate (various `Supabase*Repository.swift`, `SwiftData*Store.swift` files).
