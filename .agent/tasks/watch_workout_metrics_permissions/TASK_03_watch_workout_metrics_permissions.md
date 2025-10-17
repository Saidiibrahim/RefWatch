---
task_id: 03
plan_id: PLAN_watch_workout_metrics_permissions
plan_file: ../../plans/watch_workout_metrics_permissions/PLAN_watch_workout_metrics_permissions.md
title: Wire view model and UI to live workout metrics
phase: Phase 3 – UI Integration
---

## Goal
Surface live workout data in the watch session UI and cover the new behaviours with tests.

## Steps
1. Subscribe to the tracker's live metrics stream inside `WorkoutModeViewModel`, storing the latest values while a session is active, handling stream completion/cancellation, and resetting state when the session ends or restarts.
2. Update `WorkoutSessionHostView` (and supportive views) to prioritise live metrics when available, falling back to summary data for completed sessions.
3. Add tests validating metric propagation, stream teardown, UI behaviour, and the updated authorization display logic; run the relevant watchOS target to confirm the banner hides and live values populate.
