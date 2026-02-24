# watchOS Architecture

## Entry Points
- `RefWatchApp.swift` configures the watch scene.
- `AppRootView` handles onboarding versus active match routing.
- `MatchRootView` hosts active match UI, timer face selection, and actions sheets.

## Core Services
- `TimerManager` controls match and period clocks and publishes state.
- `MatchHistoryService` stores recent matches and supports restoration.
- `PenaltyManager` encapsulates foul tracking and notifications.

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
