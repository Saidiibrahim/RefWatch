# Purpose / Big Picture
Ensure the watch app launches into the mode switcher before any match/workout UI, and make the start-match back navigation return to the match home instead of the mode switcher, so users keep a reliable flow between MatchRootView and StartMatchOptionsView.

# Surprises & Discoveries
- (none yet)

# Decision Log
- Decision: Gate initial app load behind inline ModeSwitcherView when no persisted mode instead of auto-presenting a cover.
  Rationale: Guarantees first screen is the mode selector and avoids landing on MatchRootView before a choice is made.
  Date/Author: 2025-12-03 / Codex
- Decision: Use navigation dismiss for StartMatchScreen back action instead of reopening ModeSwitcher.
  Rationale: Back arrow should return to MatchRootView to continue match flow rather than re-entering mode selection.
  Date/Author: 2025-12-03 / Codex

# Outcomes & Retrospective
- (pending)

# Context and Orientation
- `RefWatchWatchOS/App/AppRootView.swift` currently defaults `AppModeController` to `.match` and uses a `fullScreenCover` shown on appear to present `ModeSwitcherView`, so the underlying `MatchRootView` shows first run.
- `RefWatchWatchOS/Features/Match/Views/StartMatchScreen.swift` puts a back button that triggers `modeSwitcherPresentation`, sending users to `ModeSwitcherView` rather than popping back to `MatchRootView`.
- `RefWatchWatchOS/App/ModeSwitcherEnvironment.swift` provides the mode switcher presentation binding and block reason; the block should remain respected when exiting active sessions.

# Plan of Work
1) Create targeted tasks documenting investigation and the two fixes (initial landing and start-flow back navigation).
2) Update `AppRootView` to render `ModeSwitcherView` as the initial surface when no persisted mode exists, while keeping the existing guarded switcher for later toggles.
3) Adjust `StartMatchScreen` back handling to dismiss to `MatchRootView` instead of invoking the mode switcher; ensure lifecycle transitions still dismiss start flow automatically.
4) Smoke-check navigation logic and update documentation/testing notes.

# Concrete Steps
- TASK_01_mode_switcher_navigation.md — Capture current behavior notes and confirm entry/back flows.
- TASK_02_mode_switcher_navigation.md — Implement AppRootView initial landing change.
- TASK_03_mode_switcher_navigation.md — Fix StartMatchScreen back navigation to return to MatchRootView.

# Progress
[x] (TASK_01_mode_switcher_navigation.md) Document current flows and expected changes. (2025-12-03)
[x] (TASK_02_mode_switcher_navigation.md) AppRootView initial landing fix implemented. (2025-12-03)
[x] (TASK_03_mode_switcher_navigation.md) StartMatchScreen back navigation adjusted. (2025-12-03)

# Testing Approach
- Manual reasoning + targeted simulator run (if time permits): launch with no persisted mode, ensure first screen is ModeSwitcher; start match -> back arrow returns to MatchRootView; verify mode switcher still opens via toolbar and is blocked during active match/workout.

# Constraints & Considerations
- Sandbox with restricted network; rely on local inspection without external fetches.
- Avoid altering mode-blocking semantics for active sessions.
