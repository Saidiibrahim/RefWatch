---
task_id: 04
plan_id: PLAN_workout_selection_redesign
plan_file: ../../plans/PLAN_workout_selection_redesign.md
title: Integrate preview/session flow and add regression tests
phase: Phase 4 - Flow Integration & Validation
---

### Goals
- Present the dedicated `WorkoutSessionPreviewView` when dwell selection completes, ensuring the user can scroll back to the carousel without ending the pending session and that `.starting`/`.error` presentations are reflected in the UI.
- Wire explicit start actions to invoke the existing quick start/preset methods, transition from preview to `.starting` to the live `WorkoutSessionHostView`, and surface retry/abandon paths when HealthKit start fails.
- Update automated tests and add any new ones covering preview-to-session transitions, abandonment, error recovery, and mode switching.

### Deliverables
- Modified `WorkoutRootView` (or new coordinator view) handling presentation enum changes, including `.starting` and `.error` states.
- Expanded watchOS tests validating selection, preview, error recovery, and active session flows with service stubs.

### Exit Criteria
- Preview/start flows function end-to-end in simulator, unit/UI tests pass, and regression checks for permissions/history succeed.

### Status
- 2025-02-27 — Completed preview polish, added crown-return helper, and expanded `WorkoutModeViewModel` tests; watch unit suite currently blocked by simulator launch crash (documented for follow-up).
