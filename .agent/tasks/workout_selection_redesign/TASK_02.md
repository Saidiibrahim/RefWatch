---
task_id: 02
plan_id: PLAN_workout_selection_redesign
plan_file: ../../plans/PLAN_workout_selection_redesign.md
title: Extend WorkoutModeViewModel for selection state
phase: Phase 2 - State & ViewModel Extensions
---

### Goals
- Define a `WorkoutSelectionItem` (or similar) model that unifies quick starts and presets with stable identifiers and presentation metadata.
- Add published properties for selection items, the currently focused item, dwell state, and a presentation enum separating list, preview, and active session modes.
- Ensure permission and history data remain accessible and that state transitions do not prematurely start HealthKit sessions.
- Guard against concurrent HealthKit activity by suppressing dwell-triggered starts when an external session is active and by handling authorization changes or HealthKit restrictions mid-flow.

### Deliverables
- Updated `WorkoutModeViewModel` API documenting new state and helper methods.
- Unit coverage that validates dwell timers/transitions using in-memory service stubs.
- Error-handling paths that surface `.error` presentation and allow retry/abandon without leaking HealthKit sessions.

### Exit Criteria
- View model compiles with new state, tests cover selection transitions/error handling, and existing behaviors (authorization refresh, session lifecycle) remain intact.
