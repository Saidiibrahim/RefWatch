---
task_id: 02
plan_id: PLAN_watch_sync_feedback
plan_file: ../../plans/watch_sync_feedback/PLAN_watch_sync_feedback.md
title: Implement snapshot payload safeguards and size telemetry
phase: Phase 2 - Snapshot Resiliency
---

## Objective
Prevent stale or oversized aggregate snapshots from corrupting the watch library by enforcing identifier-based sequencing, pruning outdated chunks, and surfacing payload size diagnostics.

## Scope
- Introduce snapshot identifiers (e.g., UUID or `generatedAt` composite) to chunk records and coordinator logic.
- Discard partial chunk sets when newer snapshots begin; ensure chunk store resets atomically.
- Capture encoded payload sizes during delta/snapshot dispatch and emit telemetry/notifications when approaching WatchConnectivity limits.
- Explore gzip compression or chunk splitting for oversized envelopes and document the chosen strategy.

## Deliverables
- Updated `WatchAggregateSnapshotChunkStore` and `WatchAggregateSyncCoordinator` with sequencing guards.
- Connectivity client instrumentation that records payload sizes prior to dispatch.
- Unit tests ensuring out-of-order chunk delivery skips stale data and that large payloads trigger safeguards.
