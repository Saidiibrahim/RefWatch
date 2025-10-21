---
task_id: 03
plan_id: PLAN_watch_sync_aggregates
plan_file: ../../plans/watch_sync_aggregates/PLAN_watch_sync_aggregates.md
title: Design watch-side storage and update pipeline
phase: Phase 3 - watchOS Architecture
---

## Objective
Select and document the persistence + presentation strategy that lets the watch consume aggregate payloads and expose them to existing view models or new adapters.

## Scope
- Evaluate current watch storage (JSON via `MatchHistoryService`) and design a SwiftData-based cache/outbox for aggregates, noting watchOS persistence limits and schema requirements.
- Determine how payloads map to watch domain models, including lightweight DTOs and any transformations, plus how to mark outgoing events as synced after iOS acknowledgement.
- Plan UI update mechanisms (Observation, environment injections, or dedicated controllers) to refresh lists when sync completes and to expose “last synced” status for Settings screens.

## Deliverables
- Recommended SwiftData schema (models, relationships, migration notes) with fallback considerations if SwiftData availability changes.
- Data flow description from payload receipt/manual sync trigger to persisted state, ack handling, and UI notification.
- List of additional protocols/adapters needed for testability.

## SwiftData Schema
- Added dedicated models under `RefZoneWatchOS/Core/Persistence/SwiftData/`:
  - `AggregateTeamRecord` with cascaded `AggregatePlayerRecord`/`AggregateTeamOfficialRecord` children, mirroring payload fields (`ownerSupabaseId`, `lastModifiedAt`, `remoteUpdatedAt`, colors, division) and carrying `needsRemoteSync` for watch-authored edits.
  - `AggregateCompetitionRecord`, `AggregateVenueRecord`, and `AggregateScheduleRecord` storing metadata required for roster selection and upcoming match displays (kickoff, status, notes, geo info).
  - `AggregateDeltaRecord` capturing outbound change envelopes (`id`, `entityRaw`, `actionRaw`, `payloadData`, dependencies, idempotency metadata, retry bookkeeping).
  - `AggregateSyncStatusRecord` holding singleton diagnostics (last snapshot timestamps, connectivity flag echo, `requiresBackfill`).
- Schema surfaced via `WatchAggregateModelSchema.schema`, and `WatchAggregateContainerFactory` builds persistent or in-memory containers with graceful fallback.

## Data Flow
1. `WatchAggregateLibraryStore` exposes typed fetches for teams/competitions/venues/schedules and utilities to load/update the singleton status record. `wipeAll()` clears state on sign-out.
2. `WatchAggregateDeltaOutboxStore` enqueues `AggregateDeltaEnvelope` instances, tracks retry attempts, and deletes entries when acknowledgement IDs arrive.
3. Upcoming pipeline work will:
   - Buffer incoming snapshot chunks, assemble complete `AggregateSnapshotPayload`s, and call a store method to replace existing aggregates atomically.
   - Update `AggregateSyncStatusRecord` with snapshot metadata (`generatedAt`, `settings`) and emit notifications for UI observers.
   - Drain `AggregateDeltaRecord`s after acknowledgement by comparing echoed IDs from the latest snapshot.

## Testability & Adapters
- Stores are initialised with injected `ModelContainer`s, enabling in-memory containers in tests (`WatchAggregateContainerFactory.makeContainer(inMemory: true)`).
- Remaining work: define a lightweight protocol (e.g. `AggregateLibraryPersisting`) abstracting `WatchAggregateLibraryStore` so snapshot coordinator and UI previews can swap in fakes.
- WCSession-driven coordinator will depend on store protocols and an encoder/decoder pair (`AggregateSyncCoding`) to keep unit tests hermetic.

## Implementation Notes (2025-10-16)
- Added `WatchAggregateSyncCoordinator` to decode snapshots, assemble chunks via `WatchAggregateSnapshotChunkStore`, replace SwiftData aggregates, and prune acknowledged deltas. Manual sync status messages feed into `AggregateSyncStatusRecord`.
- Introduced `WatchAggregateLibraryStore`, `WatchAggregateDeltaOutboxStore`, and `WatchAggregateSnapshotChunkStore` to manage SwiftData persistence. Stores surface `replaceLibrary`, chunk buffering, and outbox mutation helpers for the coordinator.
- Wired `WatchConnectivitySyncClient` to stream snapshots into the coordinator, flush pending deltas with `transferUserInfo`, and dispatch manual sync requests/status updates.
- Created `AggregateSyncEnvironment` as an `ObservableObject` publishing sync status and exposing coordinator/connectivity to SwiftUI; Settings screen now surfaces a Sync section with manual “Resync Library” control and status diagnostics.
