---
task_id: 04
plan_id: PLAN_watch_sync_feedback
plan_file: ../../plans/watch_sync_feedback/PLAN_watch_sync_feedback.md
title: Add regression tests for connectivity and HealthKit flows
phase: Phase 4 - Validation
---

## Objective
Backstop the new connectivity and HealthKit behaviours with automated tests so future changes catch regressions early.

## Scope
- Expand `WatchConnectivitySyncClientTests` to cover reachable/unreachable/error fallback paths, activation gating, and payload size warnings.
- Extend `WatchAggregateSyncCoordinatorTests` to validate chunk sequencing safeguards and stale snapshot pruning.
- Add HealthKit-focused tests (authorization manager, workout view model) to confirm optional diagnostics gating and live metrics cancellation.
- Document any remaining manual QA steps (paired device smoke tests) required beyond automated coverage.

## Deliverables
- New/updated test cases covering all critical branches introduced in Tasks 01-03.
- Test documentation summarising manual verification needs, if any.
