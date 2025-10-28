---
task_id: 01
plan_id: PLAN_workout_session_preview_layout
plan_file: ../../plans/PLAN_workout_session_preview_layout.md
title: Capture reference measurements & layout constraints
phase: Phase 1 - Layout Spec & Constraints Audit
---

### Goals
- Measure the current preview layout to understand existing button sizing, padding, and alignment relative to the view bounds.
- Extract proportional targets from the provided reference (secondary column offset, icon/play overlap, text spacing) and write them down for implementation.
- Identify any theme tokens we can reuse or gaps that require new constants/helpers.

### Deliverables
- Notes added to this task (and the plan if needed) summarizing desired sizes/offsets.
- Updated `Surprises & Discoveries` or `Constraints` sections in the plan if new considerations emerge.

### Exit Criteria
- Documented layout targets that guide the upcoming refactor, with explicit numeric or proportional values.
- Confirmation of whether additional supporting helpers (e.g., dedicated button size constants) are required.

### Notes (2025-03-15)
- Current implementation renders the activity glyph at `font(.system(size: 60))`, primary button diameter `76`, and secondary buttons at `38` with corner overlay. These values do not scale with watch size and drive the misalignment.
- Reference composition suggests:
  - Secondary column circles ~20–22% of the watch width with ~8pt vertical spacing and centered near the glyph’s vertical midpoint.
  - Primary play control roughly 1.35× the glyph height; glyph appears around 55–58pt on 45mm hardware.
  - Overlap distance between glyph and play circle ≈ 40% of the glyph width so the play control occludes the runner’s trailing edge without eclipsing it.
  - Text baseline centered below the cluster with ~12pt separation, padded +40pt trailing to clear the play button footprint.
- Proposed proportional metrics derived from the above:
  - `secondaryDiameter = clamp(minDimension * 0.22, 34, 44)`
  - `primaryDiameter = clamp(minDimension * 0.46, 70, 86)`
  - `iconSize = primaryDiameter * 0.72` (yields ~57pt when primary is 80pt)
  - `iconPrimaryOverlap = iconSize * 0.42`
  - `columnVerticalOffset = -primaryDiameter * 0.28` to align the column with the glyph center rather than the global midpoint.
- These proportional targets will feed the geometry helper struct in Task 02 to keep layout consistent across watch sizes.
