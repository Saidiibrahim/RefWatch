---
task_id: 02
plan_id: PLAN_mode-switcher-ux
plan_file: ./PLAN_mode-switcher-ux.md
title: Unify back affordance and blocked-state feedback
phase: UX Alignment
---

- [ ] Update `ModeSwitcherView` toolbar button to icon-only chevron and align padding/placement with other roots (Match/Workout already chevron-only).
- [ ] Decide on and implement a consistent disabled/hidden strategy for mode switching during active sessions (prefer disabled with visual hint over invisible) in `MatchRootView` and `WorkoutRootView`; ensure the control cannot fire `modeSwitcherPresentation` while blocked.
- [ ] Add user-facing cue when blocked (e.g., tooltip/alert copy: "Finish or abandon match to switch modes") without cluttering idle state.
- [ ] Verify interplay with `modeSwitcherPresentation` environment binding so disabled state cannot still trigger presentation.
- [ ] Ensure presenter/content clarity: `AppRootView` remains the single presenter for `ModeSwitcherView`; avoid adding duplicate presentation paths.
- [ ] Implement (or design) a centralized guard in `AppRootView` or the env binding that prevents mode switcher presentation during active sessions, and surfaces a consistent hint.
