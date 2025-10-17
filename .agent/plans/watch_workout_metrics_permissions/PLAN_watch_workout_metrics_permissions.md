# PLAN_watch_workout_metrics_permissions

## Purpose / Big Picture
Ensure referees experience a clean workout flow on watchOS by (1) hiding the Health permissions banner once all critical metrics are granted and (2) surfacing live workout metrics instead of placeholder `--` values during active sessions. After this work, the permissions card only reappears when essential HealthKit access is missing, and the workout session screen continuously reflects current distance, heart rate, and energy burn.

## Surprises & Discoveries
- Observation: The watch authorization manager treats any denied read sample (e.g. VO₂ Max) as a limitation, leaving `authorization.state` at `.limited`.
  - Evidence: `HealthKitWorkoutAuthorizationManager.hasLimitedReadAccess()` checks all `readTypes`, including optional VO₂ Max (`RefZoneWatchOS/Core/Platform/Workout/HealthKitWorkoutAuthorizationManager.swift:30-98`).
- Observation: Live metrics never populate because we only read `WorkoutSession.summary`, which is filled after `finishWorkout`, and all `HKLiveWorkoutBuilderDelegate` callbacks are ignored.
  - Evidence: `WorkoutSessionHostView.primaryMetrics` pulls from `session.summary` (`RefZoneWatchOS/Features/Workout/Views/WorkoutSessionHostView.swift:553-583`), while delegate methods in `HealthKitWorkoutTracker` are empty (`RefZoneWatchOS/Core/Platform/Workout/HealthKitWorkoutTracker.swift:215-238`).

## Decision Log
- Decision: Treat VO₂ Max (and other optional samples) as non-blocking so `.authorized` reflects the granted critical metrics.
  - Rationale: The watch permission prompt does not offer VO₂ Max, so flagging `.limited` blocks the UI even when workouts can be tracked normally.
  - Date/Author: 2025-02-14 / Codex
- Decision: Stream incremental summaries from `HealthKitWorkoutTracker` through the session tracker protocol instead of polling HealthKit directly from views.
  - Rationale: Keeps HealthKit coupling inside the tracker layer and lets both watchOS and iOS reuse a single update surface.
  - Date/Author: 2025-02-14 / Codex

## Outcomes & Retrospective
*TBD after implementation.*

## Context and Orientation
The watch workout flow lives under `RefZoneWatchOS/Features/Workout/`. `WorkoutHomeView.swift` displays permissions cards and entry points. Authorization state comes from `WorkoutModeViewModel` (`RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`), which relies on `HealthKitWorkoutAuthorizationManager` (`RefZoneWatchOS/Core/Platform/Workout/HealthKitWorkoutAuthorizationManager.swift`). Active sessions are presented with `WorkoutSessionHostView.swift`, whose primary metrics derive from `WorkoutSession.summary` (`RefWorkoutCore/Sources/RefWorkoutCore/Domain/WorkoutSession.swift`). HealthKit integration resides in `HealthKitWorkoutTracker` (`RefZoneWatchOS/Core/Platform/Workout/HealthKitWorkoutTracker.swift`), implementing `WorkoutSessionTracking` defined in `RefWorkoutCore/Sources/RefWorkoutCore/Protocols/WorkoutSessionTracking.swift`. Currently, the tracker only updates summaries after ending a session and does not surface live data.

## Plan of Work
Phase 1 – Authorization UX
1. Split required vs optional read sample types in `HealthKitWorkoutAuthorizationManager` and adjust `hasLimitedReadAccess()` to only flag missing mandatory metrics (distance, heart rate, active energy). Preserve optional coverage (VO₂ Max) in diagnostics but do not block `.authorized`.
2. Extend `WorkoutAuthorizationStatus` (or add a helper) to surface whether limitations are critical vs optional. Update `WorkoutModeViewModel` and `WorkoutHomeView` so the permissions card hides when only optional metrics are missing, while surfacing a lightweight “optional metrics unavailable” banner/badge elsewhere for diagnostics.
3. Update unit tests / stubs if they rely on the old `.limited` behaviour.

Phase 2 – HealthKit Live Metrics Plumbing
4. Introduce a lightweight live metrics model (e.g. `WorkoutLiveMetrics` with energy, heartRate, distance) in `RefWorkoutCore` and extend `WorkoutSessionTracking` with an `AsyncStream<WorkoutLiveMetrics>` accessor (plus a Combine publisher wrapper for existing consumers).
5. Update `HealthKitWorkoutTracker` to compute rolling statistics inside `HKLiveWorkoutBuilderDelegate` callbacks, push them through the new stream, and keep `ManagedSession.model.summary` in sync for end-of-workout persistence.
6. Update every `WorkoutSessionTracking` implementation (watchOS tracker, iOS mirror/live trackers, stubs) and their factories to adopt the streaming signature.
7. Update `WorkoutSessionTrackerStub` to emit predictable live metrics for tests.

Phase 3 – UI Integration
8. Update `WorkoutModeViewModel` to subscribe to the tracker’s live metrics stream when a session starts, caching the latest update, resetting state on completion/cancellation, and avoiding stale values during re-entry.
9. Modify `WorkoutSessionHostView` (and supporting views) to prioritise live metrics during active sessions, falling back to summary for completed workouts.
10. Add targeted tests for the view model to ensure metrics updates propagate and the permissions state hides the card when only optional samples are missing.

## Concrete Steps
- TASK_01_watch_workout_metrics_permissions.md – Refine authorization handling (Phase 1).
- TASK_02_watch_workout_metrics_permissions.md – Implement live metrics streaming in trackers (Phase 2).
- TASK_03_watch_workout_metrics_permissions.md – Wire view model & UI to new metrics + adjust tests (Phase 3).

## Progress
[x] (TASK_01_watch_workout_metrics_permissions.md) Authorization limited-state handling adjustments.
[x] (TASK_02_watch_workout_metrics_permissions.md) HealthKit tracker live metrics stream.
[x] (TASK_03_watch_workout_metrics_permissions.md) View model & UI integration plus tests.

## Testing Approach
- Unit tests for authorization logic, including coverage for optional-only limitations and the diagnostics badge (`RefZoneWatchOSTests`).
- Unit tests / async-sequence tests for the live metrics stream (`HealthKitWorkoutTracker` and `WorkoutSessionTrackerStub`) plus cancellation/cleanup behaviour.
- View model tests asserting live metrics propagation, stream teardown on session end, and optional permission banner visibility.
- Simulator-based watchOS run verifying the permissions card hides after granting core HealthKit access.
- On-device (or simulator with mocked metrics) workout session verifying live metric values update continuously.

## Constraints & Considerations
- Must maintain compatibility with iOS implementations of `WorkoutSessionTracking`; protocol changes require updates to both watchOS and iOS factories.
- HealthKit live updates should respect watchOS performance constraints—avoid heavy computation on delegate callbacks.
- Ensure backward compatibility for previously stored workouts whose summaries are populated only on completion.
