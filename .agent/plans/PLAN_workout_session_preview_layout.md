# PLAN_workout_session_preview_layout

## Purpose / Big Picture
- Recreate the watchOS workout session preview layout so the control cluster mirrors the industrial design reference (vertical secondary controls on the leading edge, overlapping primary play button with the activity glyph, label centered beneath).
- Ensure the layout remains balanced across 41/45/49mm watch sizes, respects safe areas, and gracefully handles loading/error states managed by `WorkoutRootView`.

## Surprises & Discoveries
- Observation: `WorkoutSessionPreviewView` currently positions the secondary controls via `.overlay(alignment: .topLeading)` which pins them to the safe-area corner instead of tracking the icon cluster’s centroid, causing the stack to float too high and left.
  Evidence: `RefZoneWatchOS/Features/Workout/Views/WorkoutSessionPreviewView.swift:46-58` anchors the control buttons to the top-leading corner and pads from the edges, independent of the central content.
- Observation: The primary play button is rendered inside a trailing-aligned `VStack` with additional offsets, so it drifts toward the lower-right rather than overlapping the workout glyph.
  Evidence: Lines `21-44` place the play control inside a trailing `HStack` with `Spacer()`s and a ZStack offset, preventing concentric alignment with the activity icon.

## Decision Log
- Decision: Use a geometry-driven container that aligns both the secondary control column and the icon/play cluster to a shared vertical axis derived from the available height.
  Rationale: A single layout reference point prevents manual offsets from diverging across device sizes and matches the reference composition.
  Date/Author: 2025-03-15 / Codex
- Decision: Model the icon + primary control as an overlapping pair with proportional sizing rather than fixed offsets, targeting a ~58pt icon and 76pt primary control with configurable overlap.
  Rationale: Keeps the relative weights consistent with the provided design while allowing theme-driven scaling later.
  Date/Author: 2025-03-15 / Codex

## Outcomes & Retrospective
- _TBD upon completion._

## Context and Orientation
- `WorkoutSessionPreviewView` (`RefZoneWatchOS/Features/Workout/Views/WorkoutSessionPreviewView.swift`) presents the pre-start state for a workout selection, consuming `WorkoutSelectionItem` metadata, loading/starting flags, and retry handlers.
- The view is routed from `WorkoutRootView` when `WorkoutModeViewModel.presentationState` is `.preview`, `.starting`, or `.error`, so layout must accommodate the spinner/error banner while keeping controls reachable.
- Current structure uses a `ZStack` with a centered `VStack` for icon/title, a trailing `HStack` for the primary button, and a top-leading overlay for secondary controls—each positioned independently, yielding misaligned composition compared to the reference watch design.
- Visual target: vertical column of `chevron.left` and `xmark` buttons hugging the leading edge, central activity glyph partially occluded by a dominant play circle, and the workout title centered beneath; the spinner/retry icon should replace the play circle without shifting geometry.

## Plan of Work
1. **Layout Spec & Constraints Audit** — Measure the existing preview geometry, derive desired relative positions/spacing from the reference mock, and codify sizing tokens (button diameters, overlaps, vertical offsets) that can map to the theme. Capture findings in task notes and update the plan if constraints shift.
2. **Geometry-Driven Layout Implementation** — Refactor `WorkoutSessionPreviewView` to use a single `GeometryReader`-backed container that positions the secondary button stack, icon, primary control, and text from shared anchors. Replace manual `Spacer` hacks with computed offsets and introduce helpers for consistent sizing.
3. **Error/Loading Polish & Regression Pass** — Reintegrate the loading spinner and error banner within the new layout, verify theme responsiveness, and exercise SwiftUI previews on 41/45/49mm canvases to ensure the composition holds. Adjust haptics triggers if layout changes affect focus timing.

## Concrete Steps
- `.agent/tasks/workout_session_preview_layout/TASK_01.md` – Document layout targets and sizing constraints from reference imagery. *(Phase 1)*
- `.agent/tasks/workout_session_preview_layout/TASK_02.md` – Implement geometry-aligned layout in `WorkoutSessionPreviewView`. *(Phase 2)*
- `.agent/tasks/workout_session_preview_layout/TASK_03.md` – Reflow error/loading affordances, validate previews, and capture adjustments. *(Phase 3)*

## Progress
- [x] (TASK_01_workout_session_preview_layout.md) Captured proportional targets for controls/icon overlap. *(2025-03-15 11:20)*
- [x] (TASK_02_workout_session_preview_layout.md) Implemented geometry-driven layout with anchor-based secondary controls; build blocked by SwiftPM cache sandbox. *(2025-03-15 12:50)*
- [x] (TASK_03_workout_session_preview_layout.md) Error/loading overlay polished; proportional metrics verified analytically pending Canvas preview. *(2025-03-15 13:05)*

## Testing Approach
- Exercise SwiftUI previews for `WorkoutSessionPreviewView` across simulated device sizes (41/45/49mm) to confirm alignment and control hit areas.
- Manual smoke-test in simulator (if feasible) navigating from `WorkoutHomeView` to ensure the layout integrates with real data and state transitions.
- Run relevant watchOS snapshot or unit tests if layout impacts them (currently none expected, but run `xcodebuild` target `RefZoneWatchOSTests` if new logic is introduced).

## Constraints & Considerations
- Maintain accessibility: ensure VoiceOver read order follows secondary controls → icon/play → title → error messages, and spacing supports larger dynamic type without clipping.
- Respect safe areas on both rounded and flat display corners; avoid absolute offsets that could clip on 41mm devices.
- Spinner/retry states must reuse the primary control footprint so the content doesn’t jump when errors occur.
- Simulator builds within the sandboxed CLI currently fail during SwiftPM package resolution (`~/.cache/clang/ModuleCache` not writable); local verification in Xcode will still be required to confirm visuals.
