---
task_id: 01
plan_id: PLAN_watch-timer-readability
plan_file: ./PLAN_watch-timer-readability.md
title: Implement timer readability semantics and adaptive size update
phase: Implementation
---

- [x] Increase elapsed-vs-remaining distinction in `StandardTimerFace` and `GlanceTimerFace` using typography/color hierarchy.
- [x] Increase timer prominence with adaptive scaling that respects compact/standard/expanded watch layouts.
- [x] Align `ProStoppageFace` semantics with elapsed/remaining accessibility and color hierarchy.
- [x] Remove on-screen `MATCH`/`LEFT` labels after compact-fit validation and preserve differentiation using size/color hierarchy.
- [x] Fix `ProStoppageFace` tap-target conflict so stoppage toggles do not also trigger pause/resume.
- [x] Add accessibility labels/values for timer metrics so VoiceOver users receive the same distinction.
- [x] Build watch target on Apple Watch Series 9 (45mm) simulator and confirm successful compilation.
