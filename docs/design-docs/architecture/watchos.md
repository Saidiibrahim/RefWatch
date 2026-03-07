# watchOS Architecture

## Entry Points
- `RefWatchApp.swift` configures the watch scene.
- `AppRootView` handles onboarding versus active match routing.
- `MatchRootView` hosts active match UI, timer face selection, and actions sheets.

## Core Services
- `TimerManager` controls match and period clocks and publishes state.
- `MatchHistoryService` stores recent matches and supports restoration.
- `PenaltyManager` encapsulates foul tracking and notifications.
- `BackgroundRuntimeSessionController` manages `WKExtendedRuntimeSession` for best-effort quick-return continuity while match flow is active.
  - Scope includes in-play, halftime, between-period waiting states, and penalties.
  - Runtime restart policy is reason-aware and simulator-safe; startup-failure loops are bounded.
  - Proactive self-care renewal can chain while inactive only when an existing runtime session is already running, to preserve wrist-down continuity without broadening inactive cold starts.
  - Reconciliation is triggered from `MatchRootView` on `.inactive` and `.active` scene-phase changes.

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
- Focus on ViewModel logic (timer state, penalty thresholds).
- Use watchOS UI tests for end-to-end match flow validation.
