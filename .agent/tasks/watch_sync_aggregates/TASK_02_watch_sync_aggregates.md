---
task_id: 02
plan_id: PLAN_watch_sync_aggregates
plan_file: ../../plans/watch_sync_aggregates/PLAN_watch_sync_aggregates.md
title: Draft WCSession payload schemas and sequencing
phase: Phase 2 - Sync Contract Design
---

## Objective
Define how teams, venues, competitions, and schedules move from iOS to watchOS via WatchConnectivity, covering payload format, batching, and flow control.

## Scope
- Propose envelope structure(s) for create/update/delete events, including versioning metadata, idempotency keys echoed back to the watch, and optional flags (`requiresSnapshotRefresh`).
- Decide on transport strategy consistent with the plan decisions: `updateApplicationContext` for iPhone → watch snapshots, `transferUserInfo` for watch-originated deltas, targeted `sendMessage` for manual “sync now” requests, plus chunking/size thresholds.
- Outline sequencing rules (initial full sync vs. incremental updates), acknowledgement semantics (including `acknowledgedChangeIds`), and conflict resolution assumptions.

## Deliverables
- Written schema descriptions for each aggregate, covering both snapshot (applicationContext) and delta (transferUserInfo) envelopes with field-level notes.
- Flow diagrams or bullet sequences describing trigger → package → transmit paths, including manual sync request/response messages and ack handling/echo timing.
- Constraints checklist (size limits, chunking rules, compression options) and open questions for stakeholders.

## Snapshot Envelope (`updateApplicationContext`)
- Payload type: `AggregateSnapshotPayload` (`RefWatchCore/Sources/RefWatchCore/Domain/AggregateSyncPayloads.swift`), encoded with `AggregateSyncCoding.makeEncoder()` to guarantee fractional-second ISO8601 dates.
- Shared metadata: `schemaVersion`, `generatedAt`, optional `lastSyncedAt`, and `acknowledgedChangeIds` echoing any watch-originated delta IDs previously delivered.
- Collections: `teams`, `competitions`, `venues`, `schedules`, each mirroring SwiftData identifiers plus presentation fields (`name`, `shortName`, color hexes, kickoff, etc.) and sync metadata (`ownerSupabaseId`, `lastModifiedAt`, `remoteUpdatedAt`).
- Chunking: optional `chunk` metadata (`index`, `count`) emitted by `AggregateSnapshotBuilder` when the encoded payload would exceed the ~500 KB `updateApplicationContext` budget. Chunks arrive sequentially; watch must reassemble before committing.
- Diagnostics: optional `settings` block carrying reachability (`connectivityStatus`), the last successful Supabase pull timestamp, and `requiresBackfill` signal so the watch can surface status messaging.

## Delta Envelope (`transferUserInfo`)
- Payload type: `AggregateDeltaEnvelope` (`type: "aggregateDelta"`), containing `schemaVersion`, unique `id`, `entity`, `action`, optional binary `payload`, `modifiedAt`, `origin`, optional `dependencies`, and `idempotencyKey` (defaults to `id`).
- `payload` encodes the same structure used in snapshots for creates/updates. Deletes omit payload but still carry identifiers.
- `requiresSnapshotRefresh` flags scenarios where iOS should push a fresh snapshot after reconciling with Supabase (e.g. cascading deletes).
- Envelopes travel via `transferUserInfo` for durability; when WCSession is reachable they may be optimistically mirrored through `sendMessage`.

## Manual Sync & Status Messaging
- Watch → iOS: `ManualSyncRequestMessage` (`type: "syncRequest"`) dispatched with `sendMessage` to prompt immediate Supabase refresh and snapshot generation. `Reason` distinguishes manual user action vs. connectivity-triggered recovery.
- iOS → Watch: `ManualSyncStatusMessage` (`type: "syncStatus"`) reflects `reachable`, `queued`, `queuedDeltas`, `pendingSnapshotChunks`, and `lastSnapshot`. Sent opportunistically after queueing snapshots and when manual sync completes.

## Sequencing & Constraints
- Snapshot generation is triggered by store publisher updates and manual refreshes; queues are flushed only when signed in and WCSession activation succeeds. `IOSConnectivitySyncClient.enqueueAggregateSnapshots(_:)` records pending chunk counts for diagnostics.
- Watch ingestion must treat any missing chunk as a retry condition; ack IDs are persisted only after all chunks in a generation apply successfully.
- Size guardrails: builder currently targets 450 KB maximum payload size; chunking kicks in when optimistic encoding exceeds this limit, and logs errors if individual records still overshoot.
- Open questions: whether to compress payloads (deferred pending measurement), and how aggressive the watch delta batching should be while offline (to be validated during implementation).
