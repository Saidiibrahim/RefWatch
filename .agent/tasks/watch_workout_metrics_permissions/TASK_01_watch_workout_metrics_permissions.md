---
task_id: 01
plan_id: PLAN_watch_workout_metrics_permissions
plan_file: ../../plans/watch_workout_metrics_permissions/PLAN_watch_workout_metrics_permissions.md
title: Refine HealthKit authorization handling on watchOS
phase: Phase 1 – Authorization UX
---

## Goal
Allow the permissions banner to disappear after core HealthKit metrics are granted by treating optional samples as non-blocking.

## Steps
1. Update `RefZoneWatchOS/Core/Platform/Workout/HealthKitWorkoutAuthorizationManager.swift` to distinguish mandatory vs optional read types and adjust `hasLimitedReadAccess()` to only flag missing essentials (distance, heart rate, energy). Persist optional sets for diagnostics.
2. Introduce helpers on `WorkoutAuthorizationStatus` (or a dedicated utility) to expose whether limitations are critical. Update `WorkoutModeViewModel` and `WorkoutHomeView` to hide the permissions card when only optional metrics are missing, while surfacing a lightweight diagnostics banner/badge when optional reads remain unavailable.
3. Refresh affected previews/tests (e.g. `WorkoutModeViewModel` tests) to cover the new logic.
