---
task_id: 03
plan_id: PLAN_watch_sync_feedback
plan_file: ../../plans/watch_sync_feedback/PLAN_watch_sync_feedback.md
title: Improve HealthKit optional metric UX and concurrency handling
phase: Phase 3 - HealthKit Experience
---

## Objective
Deliver clearer optional-metric messaging and safer live metrics streaming by differentiating unprompted permissions, guarding VO₂ availability, and serialising continuation access.

## Scope
- Track authorization prompt attempts in `HealthKitWorkoutAuthorizationManager` and exclude `.notDetermined` optional metrics from diagnostics until after the first prompt.
- Add platform availability checks before registering VO₂ max types and adjust the optional metric list accordingly.
- Introduce an explanation flow before re-requesting optional metrics, updating `WorkoutHomeView` messaging/button logic as needed.
- Protect `HealthKitWorkoutTracker` continuation dictionary with an actor/queue and ensure `beginConsumingLiveMetrics` cannot spawn overlapping tasks.

## Deliverables
- Revised authorization manager, tracker, and workout UI handling optional metrics cleanly.
- UX copy or flow updates informing users why optional metrics are being requested again.
- Unit tests covering authorization states, VO₂ gating, and live metrics task lifecycle.
