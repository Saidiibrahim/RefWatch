# PLAN: watchOS Quick Access Layout Adjustments

## Context
The recent layout overhaul (see `docs/plans/wip/PLAN_watchOS_Layout_Compliance.md`) improved safe-area compliance across watch sizes, but fast in-match actions now rely on scrollable surfaces and dense button stacks. Referees need frictionless access to primary controls without scrolling, and several screens can offload rarely used actions to contextual menus. This plan keeps the compliance goals intact while restoring quick access and simplifying interaction flows.

## Focus Goals
- Eliminate or minimize ScrollView usage on critical live-match surfaces (event buttons, penalty shootouts, action sheets) while retaining graceful handling for extremely tight layouts.
- Introduce long-press contextual menus for secondary actions (starting with penalties) so high-priority buttons remain unobstructed.
- Preserve the sizing strategy (`WatchLayoutScale`, safe-area helpers, dynamic typography) established in the compliance plan, with explicit coverage for 41 mm through 49 mm cases.

## Phase 1 – Compact-Case Audit
- Capture reference screenshots on the Apple Watch Series 9 (41 mm) simulator for `TeamDetailsView`, `MatchActionsSheet`, `PenaltyShootoutView`, and `PenaltyFirstKickerView` to document current scrolling behavior and safe-area usage.
- Catalogue which controls must remain instantly reachable during live play versus those suitable for contextual menus.
- Review `WatchLayoutScale` tokens and safe-area utilities to ensure upcoming adjustments stay consistent with the compliance plan.

## Phase 2 – Replace Scroll-Dependent Quick-Action Layouts
- `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift`
  - Replace the top-level `ScrollView` with an adaptive container (`ViewThatFits`, size-reader) that keeps the four event buttons visible on 41 mm cases, tightening spacing via `WatchLayoutScale` when needed.
  - Keep a guarded fallback to scrolling only when Dynamic Type or accessibility text sizes exceed available height, with a visible affordance indicating additional content.
- `RefZoneWatchOS/Features/Timer/Views/MatchActionsSheet.swift`
  - Swap the current `ScrollView` for a height-aware grid that fits all primary actions without scrolling; collapse rows using `ViewThatFits` when vertical space is constrained.
  - Add previews for compact and expanded watch sizes to verify fit.
- `RefZoneWatchOS/Features/Events/Views/PenaltyFirstKickerView.swift` (and similar pickers)
  - Apply the same adaptive layout approach so selection options remain single-screen wherever possible.
- Audit other newly scrollable surfaces (e.g., `FullTimeView`, `WorkoutSessionHostView`) to confirm any remaining scroll behavior is informational rather than action-critical.

## Phase 3 – Long-Press Option Menus ✅
- `RefZoneWatchOS/Features/Events/Views/PenaltyShootoutView.swift`
  - Removed the persistent “End Shootout” button and replaced it with a long-press gesture over the active panels/banner to surface actions for undo, swapping order, and finishing the shootout while preserving quick tap access to record attempts.
  - Confirmed the gestures honor `WatchLayoutScale` spacing and keep panels fully visible on compact watches.
- Documented the new interaction pattern for release notes/onboarding follow-up.

## Phase 4 – Shared Component & Theme Updates
- Update shared components (`EventButtonView`, `PenaltyTeamPanel`, related helpers) to expose interaction variants (tap vs. tap + long press) and let sizes derive from centralized tokens.
- Adjust `WatchLayoutScale` dimensions and spacing where necessary to support the non-scrolling layouts.
- Confirm haptic patterns (`WatchHaptics`) align with watchOS guidance for long-press confirmations.

## Phase 5 – Validation & QA
- Refresh previews for all touched views at 41 mm, 45 mm, and 49 mm to detect layout regressions early.
- Extend UITests to assert that event buttons and penalty controls remain accessible without scrolling on 41 mm hardware and that the new long-press menu appears and executes “End Shootout”.
- Run `xcodebuild` build/test flows targeting the 41 mm simulator, capturing updated baseline screenshots for penalties and team event screens.
- Schedule a targeted beta pass with referees to confirm discoverability and ergonomics of the long-press interactions before removing any legacy buttons permanently.

## Deliverables
- Updated watchOS layout code aligning with the above phases (implementation to follow after plan approval).
- New/updated previews and UITests safeguarding compact-case behavior.
- Documentation snippets (release notes or onboarding tips) highlighting the long-press interaction for penalty management.
