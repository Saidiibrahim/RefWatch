---
task_id: 03
plan_id: PLAN_workout_session_preview_layout
plan_file: ../../plans/PLAN_workout_session_preview_layout.md
title: Polish loading/error states & validate previews
phase: Phase 3 - Error/Loading Polish & Regression Pass
---

### Goals
- Integrate the loading spinner and error banner within the new geometry without compromising alignment or legibility.
- Verify the view across multiple preview devices and update the plan’s `Progress`/`Surprises` with any discrepancies found.
- Confirm accessibility order and ensure custom gestures (crown return) remain unaffected by layout changes.

### Deliverables
- Finalized SwiftUI view that renders correctly in default, loading, and error scenarios.
- Notes in this task or the plan documenting verification steps and remaining risks, if any.

### Exit Criteria
- SwiftUI previews demonstrate the corrected layout for all states with no clipping or misalignment.
- Plan `Progress` section updated to reflect completion, and any follow-up work captured under `Constraints & Considerations` or `Outcomes`.

### Notes (2025-03-15)
- Error banner now participates in the geometry stack via the metrics-driven overlay (bottom padding scales with device height), so the primary controls remain fixed while errors surface.
- Loading state retains the same footprint: spinner inside `primaryControl(metrics:)` reuses the computed diameter, preventing layout jumps when transitioning between `isStarting` and normal states.
- Manual reasoning check across 41/45/49mm assumptions confirms proportional metrics stay within bounds; further visual verification will be required in Xcode Canvas once sandbox limitations are lifted.
