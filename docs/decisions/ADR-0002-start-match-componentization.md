# ADR-0002 — Componentize Start Match Flow on watchOS

- Status: Accepted
- Date: 2025-09-23
- Owner: RefZone watchOS

## Context
- `StartMatchScreen.swift` mixed navigation chrome with two full-screen detail flows (`CreateMatchView` and `SavedMatchesView`).
- The monolithic file was 300+ lines, making it harder to reuse the menu cards, duplicate card styling across flows, or adjust logic without risking regressions.
- Upcoming layout work (chore/watchos-layout-compliance) expects Start Match UI pieces to be shared across timer entry points and previews.
- We already have a `Core/Components` directory for watchOS primitives; Start Match did not yet participate in that sharing model.

## Decision
- Extract the Start Match subviews into dedicated, reusable components under `RefZoneWatchOS/Core/Components/MatchStart/`:
  - `StartMatchOptionsView` renders the two primary actions (select/create) and exposes closures so callers own navigation while guaranteeing `reset` fires first.
  - `MatchSettingsListView` hosts the create flow list, exposes bindings for `MatchViewModel`, and emits an `onStartMatch` callback instead of depending on navigation context.
  - `SavedMatchesListView` renders the saved match list and reports selection through a closure so the parent can coordinate routing.
- Refactor `StartMatchScreen` to compose these components, while keeping lifecycle coordination (`MatchLifecycleCoordinator`) and dismissal behavior unchanged.

## Rationale
- Keeps `StartMatchScreen` focused on orchestration and environment wiring while components own layout/interaction details.
- The closures make each component testable in isolation (no hard dependency on `MatchLifecycleCoordinator`).
- Co-locating in `Core/Components` lets other features (e.g., Smart Stack entry points or future onboarding flows) reuse the same cards without duplicating view logic.

## Implementation Notes
- Files created:
  - `RefZoneWatchOS/Core/Components/MatchStart/StartMatchOptionsView.swift`
  - `RefZoneWatchOS/Core/Components/MatchStart/MatchSettingsListView.swift`
  - `RefZoneWatchOS/Core/Components/MatchStart/SavedMatchesListView.swift`
- `StartMatchScreen` now:
  - Calls `matchViewModel.resetMatch()` via the options view before pushing deeper routes.
  - Passes `matchViewModel` into `MatchSettingsListView` and handles configuration in a local helper (`configureMatch(with:)`) before advancing the lifecycle.
  - For saved matches, the closure selects the match, triggers `goToKickoffFirst()`, and the coordinator handles dismissal.
- Each component ships with a SwiftUI preview that applies `DefaultTheme()` for quick visual QA.

## Verification
- Ran `xcodebuild -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm),OS=26.0' build`.
  - Build succeeded (existing extension version warning remains unrelated, see output in CLI session if needed).

## Follow-Ups / Tips for the Next Developer
- If additional cards (e.g., “Resume Last Match”) are required, extend `StartMatchOptionsView` to accept an array of option descriptors rather than hard-coded links.
- Consider snapshot tests for `MatchSettingsListView` and `SavedMatchesListView` once the watchOS snapshot harness is ready; the closure-based design allows injecting fake view models.
- `MatchSettingsListView` still depends on `SettingsToggleRow` and `SettingsNavigationRow` in `SettingsTabView.swift`. Moving those into `Core/Components` would further reduce coupling.
- Maintain the gesture-driven `resetMatch` behavior when adding new entry points; any new button path should reset the view model before pushing deeper navigation.

## References
- Touchpoints:
  - `RefZoneWatchOS/Features/Match/Views/StartMatchScreen.swift`
  - `RefZoneWatchOS/Core/Components/MatchStart/*`
- Related plan: `docs/plans/wip/PLAN_watchOS_Layout_Compliance.md`
