---
task_id: 03
plan_id: PLAN_multi-substitution-watchos
plan_file: ./PLAN_multi-substitution-watchos.md
title: Add batch save semantics and substitution display updates
phase: Shared logic
---

- [x] Add a shared `recordSubstitutions(team:substitutions:)` entry point that records multiple substitution events from one frozen snapshot.
- [x] Increment home/away substitution tallies by batch size.
- [x] Clear stale substitution confirmation state after batch saves so the watch timer surface does not imply only the last substitution was saved.
- [x] Update substitution display formatting to show number/name combinations instead of only number-only pairs.
- [x] Keep batch saves as individual substitution events so existing undo behavior remains unchanged.
