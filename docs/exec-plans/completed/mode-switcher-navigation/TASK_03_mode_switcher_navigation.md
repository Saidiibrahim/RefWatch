---
task_id: 03
plan_id: PLAN_mode_switcher_navigation
plan_file: ./PLAN_mode_switcher_navigation.md
title: Fix StartMatchScreen back navigation
phase: Implementation
---

- Replace mode-switcher trigger with navigation dismiss so back arrow returns to `MatchRootView`.
- Keep lifecycle change handling that auto-dismisses when moving past idle.
- Confirm accessibility label/back behaviour remains appropriate.
