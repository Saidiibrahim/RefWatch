---
task_id: 03
plan_id: PLAN_mode-switcher-ux
plan_file: ./PLAN_mode-switcher-ux.md
title: Improve first-run experience and mode card clarity
phase: UX Design
---

- [ ] Redefine first-run flow: allow dismiss or gentle nudge (copy + optional learn-more link) instead of hard block; ensure selection still persists via `AppModeController`.
- [ ] Rename navigation title and remove redundant section header; tighten copy for mode descriptions/taglines.
- [ ] Replace last-used treatment (icon + section) with a clearer badge or checkmark on the selected card; remove redundant "Last used" section.
- [ ] Evaluate list layout (carousel vs plain/stack) for two-mode scenario and adjust if it improves readability without regressions.
- [ ] Add an optional active-session badge/indicator on the relevant mode card to explain why switching is blocked when an active session exists.
