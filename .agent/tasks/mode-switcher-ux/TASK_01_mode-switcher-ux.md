---
task_id: 01
plan_id: PLAN_mode-switcher-ux
plan_file: ../../plans/mode-switcher-ux/PLAN_mode-switcher-ux.md
title: Audit mode switcher/back affordances and first-run gating
phase: Analysis
---

- [ ] Trace current presentation logic in `AppRootView` (first-run show, `allowDismiss` computation, `hasPersistedSelection` mutation) and capture scenarios for new vs returning users.
- [ ] Catalog navigation/back affordances across `ModeSwitcherView`, `MatchRootView`, and `WorkoutRootView` (label styles, visibility conditions, disabled states) with screenshots/notes.
- [ ] Note current last-used indicator behavior and list style (carousel with two items) plus any watchOS HIG deviations.
- [ ] Identify active-session blocks (e.g., Match root hiding back when not idle, Workout root disabling actions) and document the user-visible state.
- [ ] Document the separation of concerns between `AppRootView` (presenter/full-screen cover) and `ModeSwitcherView` (mode selector content) to avoid future duplicate UI paths; confirm there is a single selector UI.
- [ ] Propose the single source of truth for gating `showModeSwitcher` (central guard vs per-screen hiding) and the user-facing copy for blocked state.
