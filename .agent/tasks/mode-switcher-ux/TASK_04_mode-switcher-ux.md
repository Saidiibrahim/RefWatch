---
task_id: 04
plan_id: PLAN_mode-switcher-ux
plan_file: ../../plans/mode-switcher-ux/PLAN_mode-switcher-ux.md
title: Add selection feedback and safe switching guards
phase: Interaction
---

- [ ] Add haptic feedback and brief confirmation state when selecting a mode; ensure it does not stall navigation unnecessarily.
- [ ] Implement confirmation dialogs/prompts when leaving an active match/workout, persisting session state before allowing switch.
- [ ] Ensure `AppModeController` selection path persists or rolls back gracefully if the user cancels/blocked.
- [ ] Wire any help/learn-more affordance to lightweight content (inline or modal) without adding heavy navigation.
- [ ] Align interaction with the centralized guard: when blocked, present the chosen hint/alert instead of attempting presentation; when confirmed, allow the guard to open the switcher.
