# PLAN_watch-timer-readability

## Purpose / Big Picture
Improve watch timer readability so referees can instantly distinguish total match elapsed time from period remaining time, while increasing timer prominence without clipping on small watch screens.

## Context and Orientation
- Timer face components: `RefWatchWatchOS/Core/Components/TimerFaces/StandardTimerFace.swift`, `GlanceTimerFace.swift`, `ProStoppageFace.swift`.
- Host container: `RefWatchWatchOS/Features/Timer/Views/TimerView.swift`.
- Product intent baseline: `docs/product-specs/match-timer.md`.
- Primary validation target: Apple Watch Series 9 (45mm), plus compact layout safeguards.

## Plan of Work
1. Strengthen elapsed-vs-remaining timer distinction with visual hierarchy and accessibility labels.
2. Increase timer prominence with adaptive scaling tied to available face height/width.
3. Validate build + simulator-target compatibility and record outcomes.

## Concrete Steps
- (TASK_01_watch-timer-readability.md) Implement timer face typography/label updates and verify watch build.

## Progress
- [x] TASK_01_watch-timer-readability.md

## Surprises & Discoveries
- Observation: Explicit `MATCH`/`LEFT` labels improved semantics but caused compact-layout overflow; compact faces required label-free differentiation.
- Evidence: Compact preview clipped the remaining-time row when labels and enlarged typography were combined.

## Decision Log
- Decision: Differentiate elapsed and remaining timers primarily through typography hierarchy and color, without requiring on-screen text labels.
- Rationale: Preserves glance clarity while fitting compact layouts more reliably.
- Date/Author: 2026-02-24 / Codex
- Decision: Use adaptive scaling (`FaceSizer` + width caps) instead of fixed font-size bumps.
- Rationale: Keeps 45mm readability gains while reducing clipping risk on compact screens.
- Date/Author: 2026-02-24 / Codex

## Testing Approach
- Build watch target:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- Manual verification:
  - Validate elapsed-vs-remaining distinction in running and paused states without on-screen labels.
  - Confirm stoppage remains visually distinct and readable.

## Constraints & Considerations
- Preserve existing tap interactions (tap to pause/resume, stoppage toggle in Pro Stoppage face).
- Keep watch-first glanceability and avoid introducing dense copy.
- Maintain accessibility parity with explicit semantic labels for timer values.

## Outcomes & Retrospective
- Completed in one implementation pass with successful watch build validation.
- No architecture boundary changes required; behavior documented in product spec and active plan.

## Evidence Trail (Sub-Agents)
- Code-risk review (planning phase):
  - Finding: potential clipping risk with enlarged typography and missing semantic accessibility output.
  - Applied: width-aware sizing caps in timer faces and explicit accessibility labels for match vs remaining values.
- Docs/evidence review (planning phase):
  - Finding: UI behavior change required an active exec plan and product-spec linkage.
  - Applied: added this active plan/work task and updated `docs/product-specs/match-timer.md`.
- Docs/evidence review (post-change phase):
  - Finding: sub-agent audit trail needed to be recorded explicitly.
  - Applied: added this evidence section summarizing reviewer findings and dispositions.
- Code-risk review (post-change phase):
  - Finding: tap conflict in `ProStoppageFace` where stoppage-row taps could also trigger pause/resume.
  - Applied: split tap areas so the top timer cluster handles pause/resume and the stoppage row handles only stoppage toggling.
- Code-risk re-review (post-fix phase):
  - Finding: no remaining high/medium issues in updated timer faces.
  - Applied: no additional changes required.
- Docs/evidence re-review (final phase):
  - Finding: no remaining high/medium process-consistency issues.
  - Applied: no additional documentation changes required.
