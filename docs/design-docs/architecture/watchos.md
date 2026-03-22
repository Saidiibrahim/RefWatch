# watchOS Architecture

## Entry Points
- `RefWatchApp.swift` configures the watch scene.
- `AppRootView` handles onboarding versus active match routing.
- `MatchRootView` hosts active match UI, timer face selection, and actions sheets.

## Core Services
- `TimerManager` controls match and period clocks and publishes state.
- `MatchHistoryService` stores recent matches and supports restoration.
- `PenaltyManager` encapsulates foul tracking and notifications.
- `BackgroundRuntimeSessionController` manages an `HKWorkoutSession`-backed Match Mode runtime while a match is unfinished.
  - Shippable watch metadata is `WKBackgroundModes = [workout-processing]` only. Match Mode does not depend on background audio, Apple Music, or media playback.
  - Scope includes kickoff waiting, in-play, paused, halftime waiting, halftime, second-half waiting, ET waiting, penalty waiting, active penalties, and the full-time screen before final completion/reset.
  - `MatchViewModel` persists a full `ActiveMatchSessionSnapshot` so unfinished matches can rehydrate timer anchors, penalty state, and lifecycle flags after process death or relaunch.
  - `PersistedActiveMatchSessionStore` writes the snapshot into the watch App Group so `MatchRootView` can restore it on launch before routing.
  - `RefWatchApp.swift` implements `WKApplicationDelegate.handleActiveWorkoutRecovery()` and hands recovered sessions back to the runtime controller through `MatchWorkoutRecoveryBroker`.
  - `MatchLifecycleCoordinator` owns the canonical resume-route mapping for every unfinished state, including `waitingForHalfTimeStart` and `waitingForPenaltiesStart`.
  - Reconciliation is triggered from `MatchRootView` on launch and on `.inactive` / `.active` scene-phase changes.
  - Platform boundary: an active workout session is the documented continuity path under watchOS workout-session semantics, but explicit user dismissal/app switching, revoked HealthKit permission, or system termination can still interrupt frontmost state.

## Timer Faces
- ``TimerFaceModel`` (protocol) defines read-only timer state and actions.
- ``TimerFaceStyle`` selects the active face via `@AppStorage("timer_face_style")`.
- ``TimerFaceFactory`` produces SwiftUI views (e.g., ``StandardTimerFace``) rendered inside `TimerView`.

## Feature Modules
- `MatchSetup`: handles team selections, rules, and kickoff routines.
- `Match`: renders live actions, score adjustments, and penalty logging.
- `Events`: displays chronological match events for quick review.
- `Settings`: hosts personalization and integration options.

## Watch-Specific Adapters
- `WatchHaptics` implements `HapticsProviding`.
- Connectivity stubs exist for future watch-to-phone sync.

## Testing Notes
- Focus on ViewModel logic, persisted unfinished-match snapshots, and penalty/timer rehydration.
- Use watchOS simulator tests for routing/runtime-controller behavior and launch restoration.
- Release proof also requires archive/App Store validation of the watch bundle metadata, including `WKBackgroundModes = [workout-processing]` only.
- Treat simulator and physical-watch evidence separately:
  - simulator validates state restoration, routing, and compile-time HealthKit/workout integration
  - physical Apple Watch validation is still required for wrist-down return behavior, workout recovery timing, and frontmost continuity under real watchOS power policy
