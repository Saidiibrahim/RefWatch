---
task_id: 02
plan_id: PLAN_workout_session_preview_layout
plan_file: ../../plans/PLAN_workout_session_preview_layout.md
title: Implement geometry-aligned preview layout
phase: Phase 2 - Geometry-Driven Layout Implementation
---

### Goals
- Refactor `WorkoutSessionPreviewView` to rely on a `GeometryReader`-backed layout that positions all primary elements from a shared anchor.
- Ensure the secondary control stack, icon glyph, and primary play control match the documented targets and remain responsive across watch sizes.
- Replace manual padding/offset hacks with computed values encapsulated in small helpers for clarity.

### Deliverables
- Updated SwiftUI view composition using the new layout approach with clean, well-commented geometry calculations.
- Removal of obsolete alignment code (e.g., trailing `Spacer` scaffolding) without regressing functionality.

### Exit Criteria
- SwiftUI preview compiles and shows the new composition aligning closely with the reference.
- Primary states (`default`, `isStarting`, `error`) reuse the same layout footprint so controls stay put while swapping content.

### Notes (2025-03-15)
- Reworked `body` around a `GeometryReader` that feeds a shared `LayoutMetrics` struct; central cluster now anchors via an `AnchorPreference` so the secondary button column tracks the glyph’s actual center.
- Icon/play overlap handled through a negative-spacing `HStack` sized from proportional metrics (`primaryDiameter`, `iconSize`, `iconPrimaryOverlap`). Text receives additional trailing padding derived from the play control footprint to prevent overlap.
- Control column is rendered in an overlay using the captured anchor, ensuring both buttons align to the glyph centroid with responsive spacing and diameter scaling.
- Build verification blocked by sandbox restrictions on SwiftPM cache directories (`~/.cache/clang/ModuleCache`), so xcodebuild could not finish; manual review shows no syntax issues, and layout states share the same footprint via the new helper functions.
