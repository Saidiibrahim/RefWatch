---
task_id: 02
plan_id: PLAN_watch_workout_metrics_permissions
plan_file: ../../plans/watch_workout_metrics_permissions/PLAN_watch_workout_metrics_permissions.md
title: Add live HealthKit metrics streaming to workout tracker
phase: Phase 2 – HealthKit Live Metrics Plumbing
---

## Goal
Emit periodic live workout metrics from the session tracker so UI layers no longer rely on static summaries.

## Steps
1. Add a reusable live metrics model in `RefWorkoutCore` and extend `WorkoutSessionTracking` with an `AsyncStream<WorkoutLiveMetrics>` API plus a Combine wrapper for existing consumers.
2. Implement the new API inside `RefZoneWatchOS/Core/Platform/Workout/HealthKitWorkoutTracker.swift`, updating live statistics within `HKLiveWorkoutBuilderDelegate` callbacks and keeping `ManagedSession` state synchronized.
3. Update every `WorkoutSessionTracking` implementation (watchOS tracker, iOS mirror/live trackers, stubs) and supporting factories to adopt the streaming signature, emitting deterministic test data where appropriate.
