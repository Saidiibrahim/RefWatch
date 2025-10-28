# PLAN_workout_selection_redesign

## Purpose / Big Picture
- Deliver a watchOS workout launcher that mirrors the provided carousel design: a centered, crown-driven list of workouts that auto-selects after a short dwell and brings up the workout session screen without tapping.
- Preserve existing capabilities (permissions messaging, quick starts, presets, history) while making the experience easier to scan at a glance and avoiding text truncation.
- Allow referees to fluidly switch between workouts by scrolling, including re-surfacing the list from the session screen when they rotate the Digital Crown.

## Surprises & Discoveries
- Observation: `WorkoutSessionHostView` (`RefZoneWatchOS/Features/Workout/Views/WorkoutSessionHostView.swift:1`) is implemented solely for in-progress sessions (pause/resume, segment, end) and has no "pre-start" state, yet the desired flow expects to show that UI before a session begins.  
  Evidence: the timer model starts immediately during `init` and renders active metrics and control tiles (lines around 72-220).
- Observation: `WorkoutHomeView` (`RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift:15`) is a sectioned `List` optimized for cards; it cannot render the icon+label carousel without significant restructuring.  
  Evidence: sections for permissions, recent, quick start, presets each wrap `Button` rows rather than center-aligned list items (lines 16-120).
- Observation: `WorkoutModeViewModel` currently toggles only between `activeSession` and `nil` (home). There is no state for "selected workout, not yet started" required by the auto-selection flow.  
  Evidence: published properties focus on session state, quick start/preset actions immediately call `sessionTracker.startSession` (lines 160-260).

## Decision Log
- Decision: Dwell selection transitions into a preview state; workouts start only after the user taps an explicit start control.
- Rationale: Avoids unintended HealthKit sessions and lets referees review details before committing while retaining the carousel UX.
- Date/Author: 2025-02-14 / Codex

## Outcomes & Retrospective
- _TBD once implementation completes_.

## Context and Orientation
- Entry point: `WorkoutRootView` (`RefZoneWatchOS/Features/Workout/Views/WorkoutRootView.swift`) switches between `WorkoutHomeView` and `WorkoutSessionHostView` based on `WorkoutModeViewModel.activeSession`.
- Home experience: `WorkoutHomeView` renders permissions, recent workout, quick starts, and presets inside a `List` styled as cards. Selection currently happens through `Button` taps and delegates to closures supplied by the root view.
- Session experience: `WorkoutSessionHostView` uses a `TabView` for controls / metrics / media, driven by `WorkoutTimerFaceModel`. It assumes a live `WorkoutSession` from `WorkoutModeViewModel`.
- Services: `WorkoutModeViewModel` owns all interactions with `WorkoutServices` (HealthKit, history, presets) and publishes state consumed by the views.
- Design gap: the desired carousel requires a new state machine so the scroll/dwell interaction can select an item, present a preview, and optionally begin tracking.

## Plan of Work
1. **Experience Definition & Data Mapping**  
   Document the exact workout catalog to show (quick starts vs presets), how permissions/warnings surface within the carousel experience, and specify behavior for dwell selection and returning to the list. Produce acceptance notes and capture open questions (notably auto-start vs preview).
2. **State & ViewModel Extensions**  
   Introduce a `WorkoutSelectionItem` model that unifies quick starts and presets. Add published state to `WorkoutModeViewModel` for `selectionItems`, `focusedSelectionID`, and an expanded presentation state machine (e.g., `.list`, `.preview(WorkoutSelectionItem)`, `.starting(WorkoutSelectionItem)`, `.session(WorkoutSession)`, `.error(WorkoutSelectionItem, WorkoutError)`). Document transitions, ensure timers cancel when focus shifts, and keep HealthKit interactions gated until the `.starting` phase completes successfully.
3. **Carousel Selection UI**  
   Replace `WorkoutHomeView` with a new vertically-centered carousel that uses `ScrollPositionReader` plus Digital Crown updates to track focus. Implement dwell detection (target 1–2 s) driven by crown velocity/scroll changes, cancel when kinetic scrolling is active, and surface haptic feedback when the dwell locks. Make space for permission diagnostics (overlay or leading tile) and persist the last focused item so returning from preview restores position.
4. **Session Preview & Flow Integration**  
   Build a dedicated `WorkoutSessionPreviewView` that mirrors session chrome without instantiating live metrics. Update `WorkoutRootView` to react to the new presentation enum, hand off from preview to `.starting` to the existing `WorkoutSessionHostView`, and surface retry/abandon affordances when `.error` occurs. Scrolling back from preview/session should re-expose the carousel without tearing down an in-flight start attempt.
5. **Testing & Iteration**  
   Add unit tests around the new state machine, dwell timer behavior, and error handling. Update snapshot/previews for the new UI and run watchOS previews/manual smoke tests. Ensure backwards compatibility for history/presets and verify interactions with the mode switcher, concurrent sessions, and HealthKit failure scenarios.

## Experience Contract *(2025-02-18)*
- **Catalog ordering** — Present items in the following sequence: (1) authorization tile (shown whenever `authorization.state != .authorized` or optional metrics are denied), (2) last completed workout tile when available, (3) quick starts (`outdoorRun`, `outdoorWalk`, `strength`, `mobility`), (4) saved presets in the order returned by `WorkoutPresetStore`. Empty presets render a dedicated “Add presets in RefZone iPhone” informational tile instead of a blank slot. All catalog entries conform to the upcoming `WorkoutSelectionItem` model.
- **Permission messaging** — Authorization tile surfaces the current status string (re-using `WorkoutPermissionsCard` copy) and exposes a single primary action that routes to `onRequestAccess`. Diagnostics badges (optional metric warnings) render as part of the authorization tile footer so that the carousel does not need a second entry.
- **Recent workout** — The “last completed” tile mirrors the summary from `WorkoutSummaryCard` (duration + distance) and allows a quick relaunch by dwelling; the preview view will highlight that this is a repeat of the previous session.
- **Dwell mechanics** — Dwell triggers after **1.25 s** of stable focus where absolute crown velocity remains below **0.15 rad/s** and scroll offset change stays under **6 pt**. Velocity spikes or kinetic scrolling immediately cancel the pending dwell. A `.success` haptic plays on lock and the preview animates in without requiring a tap.
- **Return gesture** — While in preview or session, a counter-clockwise crown rotation of at least **15°** with the crown at rest for **0.3 s** re-exposes the carousel list without terminating the start attempt. This relies on the same velocity heuristics as dwell cancellation.
- **Persistence** — The last focused selection ID is cached in-memory inside `WorkoutModeViewModel` and restored when returning from preview/session so referees resume from their previous item.

### Open Questions
- None at this time; decisions above align with the product brief. Update this section if design feedback revises dwell duration or catalog ordering.

## Concrete Steps
- `.agent/tasks/workout_selection_redesign/TASK_01.md` – Capture UX contract, workout catalog ordering, and permission handling updates. *(Phase 1)*
- `.agent/tasks/workout_selection_redesign/TASK_02.md` – Extend `WorkoutModeViewModel` with selection/presentation state and supporting models. *(Phase 2)*
- `.agent/tasks/workout_selection_redesign/TASK_03.md` – Implement the carousel selection UI and dwell detection in the new home view. *(Phase 3)*
- `.agent/tasks/workout_selection_redesign/TASK_04.md` – Integrate preview/session flow, wire start actions, and add tests. *(Phase 4–5)*

## Progress
- [x] (TASK_01_workout_selection_redesign.md) UX definition & open questions. *(2025-02-18)*
- [x] (TASK_02_workout_selection_redesign.md) ViewModel state extensions. *(2025-02-18)*
- [x] (TASK_03_workout_selection_redesign.md) Carousel UI implementation. *(2025-02-20)*
- [x] (TASK_04_workout_selection_redesign.md) Flow integration & tests — preview polish complete, new haptics/tests added, pending follow-up on simulator crash impacting watch test run. *(2025-02-27)*

## Testing Approach
- Unit-test dwell timer and presentation state transitions in `WorkoutModeViewModel` using the in-memory services stubs found in `RefWorkoutCore/Sources/RefWorkoutCore/Services/WorkoutServiceMocks.swift` and existing watchOS tests.
- Exercise the new carousel via SwiftUI previews and, if feasible, watchOS UI tests to confirm layout on 41/45/49mm devices.
- Manual regression: permissions denied, history empty, presets empty, active session resume path, switching back to match mode.

## Constraints & Considerations
- watchOS scroll physics and Digital Crown events require smooth cancellation of the dwell timer; cancel when crown velocity exceeds the dwell threshold, when kinetic scrolling is still settling, or when the app moves to background.
- Continue supporting HealthKit authorization prompts/diagnostics within the simplified UI and surface clear messaging when authorization changes mid-preview.
- Prevent concurrent or duplicate session starts: ignore dwell triggers if an active session exists elsewhere, gate HealthKit calls behind `.starting`, and surface `.error` with recovery when `HKHealthStore` rejects a request.
- Provide accessibility affordances: large text, VoiceOver focus order, and haptic confirmation on dwell lock.
- Maintain compatibility with existing `WorkoutServicesFactory.makeDefault()` fallback when HealthKit is unavailable.
