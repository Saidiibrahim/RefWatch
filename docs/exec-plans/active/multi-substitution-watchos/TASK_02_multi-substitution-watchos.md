---
task_id: 02
plan_id: PLAN_multi-substitution-watchos
plan_file: ./PLAN_multi-substitution-watchos.md
title: Implement watchOS multi-substitution hub and spoke flows
phase: watchOS UI
---

- [x] Replace the old single `player off -> player on` watch substitution flow with a hub showing `Player(s) off`, `Player(s) on`, and `Done`.
- [x] Allow either side to be entered first and disable `Done` until both sides have the same non-zero count.
- [x] Use roster multi-select when a synced team roster is available for the selected match team.
- [x] Add numeric batch collection fallback with add/edit/remove affordances when no roster is available.
- [x] Remove the watch UI dependence on `substitutionOrderPlayerOffFirst`.
