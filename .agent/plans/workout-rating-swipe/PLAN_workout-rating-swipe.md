# ExecPlan: Workout Rating Swipe Replacement

## Purpose / Big Picture
Replace the swipe-right media pane in `RefZoneWatchOS/Features/Workout/Views/WorkoutSessionHostView.swift` with a minimalist "Rate This Workout" experience. After a workout session runs for at least five minutes, the page should surface a single interactive dial so athletes can record difficulty (0-10) quickly. Ratings sync with existing session data so the iOS/web apps can surface difficulty trends later.

## Surprises & Discoveries
- Observation: _None yet_
- Evidence: _None yet_

## Decision Log
- Decision: Use the existing media tab slot and `WorkoutSessionMediaPage` entry point to host the rating UI for minimal routing churn.
  - Rationale: Keeps TabView wiring intact while swapping content.
  - Date/Author: 2025-10-28 / Codex

## Outcomes & Retrospective
_Pending implementation._

## Context and Orientation
- `RefZoneWatchOS/Features/Workout/Views/WorkoutSessionHostView.swift`: Hosts the workout session TabView; the third tab currently instantiates `WorkoutSessionMediaPage`.
- `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutSessionMediaViewModel.swift` (assumed existing): Powers media playback state; will be deprecated for this feature.
- `RefZoneWatchOS/Features/Workout/Models/WorkoutSession.swift`: Represents the active workout session; confirm where to persist difficulty feedback.
- `RefZoneWatchOS/Features/Workout/Data/WorkoutDifficultyFeedback.swift` (to be introduced): Model for 0-10 rating attached to session summary.
- Supabase sync layer (RefWorkoutCore) will need to ship the new rating field when syncing sessions.

Terminology: "rating dial" refers to the circular selector letting users spin Digital Crown or tap to choose 0-10. "Persist" means store locally during session and enqueue for sync when connectivity resumes.

## Plan of Work
1. Audit existing media tab usage to confirm dependencies and teardown requirements. Identify all invocations of `WorkoutSessionMediaPage` and supporting view model classes.
2. Design a new lightweight model (`WorkoutSessionRatingState`) to hold selected score, persisted value, and debounce for auto-save. Decide on state ownership (likely `WorkoutSessionHostView`) and define gating behaviors (dial hidden before five minutes, saved-state badge once a rating exists).
3. Build a new view (`WorkoutSessionRatingPage`) providing the dial UI, state callbacks, Digital Crown handling, and auto-save animation. Specify the minimal layout (title, dial with numeric readout, transient "Saved" confirmation) and ensure `.focusable` + `.digitalCrownRotation` prevents accidental TabView swipes.
4. Integrate persistence: Extend session data structures to store `difficultyRating`, update sync payloads, and ensure saving occurs immediately after selection. Confirm previously saved values repopulate when the tab opens so users can adjust mid-session.
5. Remove media playback assets, ensuring no build leftovers (framework imports, entitlements).
6. Add tests covering rating persistence and UI state transitions (e.g., pre-five-minute lockout, auto-save triggered, stored rating reloaded).
7. Update documentation/changelog to guide testers on using the new rating screen, including Digital Crown interaction tips and confirmation feedback.

## Progress
- [ ] (TASK_01_workout-rating-swipe.md) (2025-10-28) Inventory media tab dependencies and confirm removal scope.
- [ ] (TASK_02_workout-rating-swipe.md) (2025-10-28) Design rating state + persistence approach and document data flow.
- [ ] (TASK_03_workout-rating-swipe.md) (2025-10-28) Implement rating UI, integrate into host view, and add tests.

## Testing Approach
- Unit tests verifying state model saves and reloads difficulty ratings correctly.
- Snapshot or UI tests validating dial selection updates `WorkoutSessionHostView` state.
- Integration smoke test on watchOS simulator to ensure TabView navigation still works and rating auto-saves when dial interaction ends.

## Constraints & Considerations
- Must remain crown-friendly with minimal touch interaction due to workout context.
- Clarify pre-rating state so the tab never looks empty: show remaining time hint until the five-minute mark and a subtle saved badge once feedback is captured.
- Swapping out media playback may impact any shared audio entitlements; coordinate with team before removing frameworks.
- Persisted rating should default to `nil` to avoid skewing historical data before the user interacts with the dial.
- Guard against gesture conflicts by dedicating the full tab height to the dial and re-applying crown focus each time the view appears.
