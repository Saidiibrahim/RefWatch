---
task_id: 02
plan_id: PLAN_multi-substitution-watchos
plan_file: ./PLAN_multi-substitution-watchos.md
title: Implement watchOS multi-substitution hub and spoke flows
phase: watchOS UI
---

## Supersession Note
- Superseded for current precedence on 2026-03-30 by `PLAN_match-sheet-import` for newly authored scheduled matches.
- Current intended precedence is:
  - saved side-specific match sheets first for the requested side
  - numeric/manual fallback when the requested side does not have a usable saved sheet
  - synced library roster lookup only for legacy schedules with no match-sheet fields

- [x] Replace the old single `player off -> player on` watch substitution flow with a hub showing `Player(s) off`, `Player(s) on`, and `Done`.
- [x] Allow either side to be entered first and disable `Done` until both sides have the same non-zero count.
- [x] Use frozen match-sheet lineup selection when the requested side has a usable saved sheet, and retain roster multi-select only for legacy no-sheet schedules.
- [x] Add numeric batch collection fallback with add/edit/remove affordances when explicit match-sheet data is incomplete or no roster source is available.
- [x] Remove the watch UI dependence on `substitutionOrderPlayerOffFirst`.
