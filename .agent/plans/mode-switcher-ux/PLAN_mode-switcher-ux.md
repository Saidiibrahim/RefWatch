# PLAN_mode-switcher-ux

## Purpose / Big Picture
Tighten the watchOS mode selection flow so referees can switch between Match and Workout confidently, with platform-consistent navigation, gentler first-run onboarding, and clear feedback when switching or when mode switching is unavailable. The goal is to reduce accidental context switches, remove first-time friction, and make the back affordance reliably lead to mode selection without confusion.

## Suprises & Discoveries
- Observation: None yet — to be filled during implementation.
- Evidence: N/A

## Decision Log
- Decision: Standardize all watchOS back affordances to icon-only chevron (no label).
 - Rationale: Matches watchOS system convention for top-level back affordance and removes mixed styles across surfaces.
  - Date/Author: 2025-12-02 / Codex
- Clarification: The mode selector UI lives in `ModeSwitcherView` and is presented by `AppRootView`; only one UI exists, with `AppRootView` acting as the presenter (full-screen cover) and `ModeSwitcherView` providing the content. Future changes should keep this separation to avoid duplicate logic.
- Follow-up focus areas:
  - Add a central guard that blocks `showModeSwitcher` while an active session is running and surfaces user-facing copy when blocked.
  - Make `ModeSwitcherView` back affordance icon-only to match the standard.
  - Standardize blocked-state UX (disabled + hint vs hidden) for Match and Workout.
  - Decide first-run dismissal policy (re-present until selection vs keep dismiss disabled).
  - Consider an active-session badge on mode cards to explain why switching is blocked.

## Outcomes & Retrospective
- Pending — to summarize after implementation.

## Context and Orientation
- Mode selection UI: `RefZoneWatchOS/App/ModeSwitcherView.swift` (list of modes, back button, last-used indicator, carousel list).
- Root hosting/presentation: `RefZoneWatchOS/App/AppRootView.swift` (controls full-screen cover, allowDismiss logic based on `appModeController.hasPersistedSelection`).
- Match home/back affordance: `RefZoneWatchOS/App/MatchRootView.swift` (chevron-only back, hidden when not idle, disables mode switching during active match).
- Workout home/back affordance: `RefZoneWatchOS/Features/Workout/Views/WorkoutRootView.swift` (labelStyle iconOnly, disabled while performing actions).
- Mode state + persistence: `RefWatchCore/Sources/RefWatchCore/Services/AppModeController.swift` (currentMode, hasPersistedSelection, storage defaults, overrideForActiveSession).

## Plan of Work
1) Normalize navigation/back affordances across ModeSwitcher, Match root, and Workout root (icon-only chevron everywhere) and add a visible disabled state/explanation when mode switching is blocked by active sessions.
2) Improve first-run experience by allowing a graceful dismissal or guided nudge instead of a hard block; add lightweight learn-more/help affordance and copy explaining each mode.
3) Clarify mode options and feedback: rename navigation title, remove redundant “Last used” section, replace the ambiguous last-used icon, and add haptic/brief confirmation when switching.
4) Add safety for active sessions and reliability: confirmations when leaving an active match/workout, persist state before switches, and cover edge cases (force quit mid-switch, resume).
5) Testing and instrumentation: unit tests for AppModeController persistence/override, and lightweight UI/integration coverage for mode switching availability and confirmations.

## Concrete Steps
- (TASK_01_mode-switcher-ux.md) Audit current mode switcher/back affordances and document states (idle vs active match/workout, allowDismiss on first run).
- (TASK_02_mode-switcher-ux.md) Unify back button styling/behavior and add disabled/tooltip state when mode switching is blocked.
- (TASK_03_mode-switcher-ux.md) Redesign first-run experience and mode cards (copy tweaks, learn-more affordance, title/section cleanup, last-used indicator change).
- (TASK_04_mode-switcher-ux.md) Add selection feedback (haptic + confirmation), safe switching guards for active sessions, and state persistence before switching.
- (TASK_05_mode-switcher-ux.md) Add tests (AppModeController persistence/override, UI test for first-run dismissal + switch confirmation, guard when active match).

## Progress
- [ ] TASK_01_mode-switcher-ux.md
- [ ] TASK_02_mode-switcher-ux.md
- [ ] TASK_03_mode-switcher-ux.md
- [ ] TASK_04_mode-switcher-ux.md
- [ ] TASK_05_mode-switcher-ux.md

## Testing Approach
- Unit: Extend `AppModeController` tests for persistence, overrideForActiveSession, and first-run allowDismiss behavior.
- UI/Integration: watchOS UI test to cover first-run presentation/dismissal, switching with confirmation/haptic stub, and blocked switching during active match.
- Manual: simulator sanity for back affordance consistency, learn-more flow, and switch confirmation timing.

## Constraints & Considerations
- watchOS screen space is tight; keep copy concise and avoid heavy overlays.
- Mode switching should never interrupt an active match/workout without explicit confirmation and state persistence.
- Maintain feature-first architecture; keep changes localized to mode selection and root containers.
