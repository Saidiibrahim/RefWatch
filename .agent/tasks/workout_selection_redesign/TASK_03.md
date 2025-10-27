---
task_id: 03
plan_id: PLAN_workout_selection_redesign
plan_file: ../../plans/PLAN_workout_selection_redesign.md
title: Build carousel workout selection UI with dwell detection
phase: Phase 3 - Carousel Selection UI
---

### Goals
- Replace the existing `WorkoutHomeView` list with a centered carousel layout that renders icons above labels per design references.
- Implement focus tracking with `ScrollPositionReader` (or equivalent) plus Digital Crown updates, using velocity thresholds and kinetic-scroll detection to start/cancel the dwell timer and trigger preview (not auto-start) when the dwell completes.
- Persist the last focused item so returning from preview restores position, and represent permission warnings, diagnostics, and empty preset states within the new layout without sacrificing readability.

### Deliverables
- Updated SwiftUI view(s) (new or refactored) with previews demonstrating typical, empty, and permission-limited states, including haptic feedback hooks when dwell locks.
- Styling consistent with the watch theme and accommodating multiple watch sizes.

### Exit Criteria
- Carousel scrolls smoothly on device/simulator, dwell selection updates the view model, and no text truncates in tested locales.
