---
task_id: 02
plan_id: PLAN_mode_switcher_navigation
plan_file: ../../plans/mode_switcher_navigation/PLAN_mode_switcher_navigation.md
title: Implement initial landing change in AppRootView
phase: Implementation
---

- Gate root content: show `ModeSwitcherView` as initial surface when no persisted mode exists.
- Keep guarded mode switcher cover for post-selection switching; preserve confirmations/haptics.
- Ensure transition to selected mode updates workout view ID when needed.
