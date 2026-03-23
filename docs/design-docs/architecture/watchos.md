# watchOS Architecture

## Entry Points
- `RefWatchApp.swift` configures the watch scene.
- `AppRootView` handles onboarding versus active match routing.
- `MatchRootView` hosts active match UI, timer face selection, actions sheets, and the watch-only lifecycle alert overlay.

## Core Services
- `TimerManager` controls match and period clocks, publishes state, and emits semantic lifecycle haptic cues through injected adapters rather than calling WatchKit directly.
- `MatchHistoryService` stores recent matches and supports restoration.
- `PenaltyManager` encapsulates foul tracking and notifications.
- `BackgroundRuntimeSessionController` manages an `HKWorkoutSession`-backed Match Mode runtime while a match is unfinished.
  - Required watch bundle metadata is `WKBackgroundModes = [workout-processing]` only. Match Mode does not depend on background audio, Apple Music, or media playback.
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
- `WatchMatchLifecycleHaptics` implements `MatchLifecycleHapticsProviding` and owns the watch-only repeating lifecycle alert policy: `3 x 0.4s` pulses repeated every `3.0s` until explicit acknowledgment while the app is active.
- `LifecycleAlertOverlayView` is a watch-only blocking surface rendered by `MatchRootView`; it swallows background taps and keeps acknowledgment separate from timer-face interactions.
- Connectivity stubs exist for future watch-to-phone sync.

## Testing Notes
- Focus on ViewModel logic, persisted unfinished-match snapshots, and penalty/timer rehydration.
- Lifecycle haptics must be validated at two levels:
  - shared/core tests assert semantic cue requests, dedupe, persisted restore behavior, and cancellation triggers
  - watch adapter tests assert repeating-cycle scheduling, acknowledgment, and queued-pulse cancellation
- Use watchOS simulator tests for routing/runtime-controller behavior and launch restoration.
- Release proof also requires verifying built watch bundle metadata, including `WKBackgroundModes = [workout-processing]` only.
- Treat simulator and physical-watch evidence separately:
  - simulator validates state restoration, routing, and compile-time HealthKit/workout integration
  - physical Apple Watch validation is still required for wrist-down return behavior, workout recovery timing, frontmost continuity under real watchOS power policy, tactile confirmation that lifecycle haptics do not arrive late after transition/reset, and confirmation that foreground-only alerts do not resume after interruption/relaunch
