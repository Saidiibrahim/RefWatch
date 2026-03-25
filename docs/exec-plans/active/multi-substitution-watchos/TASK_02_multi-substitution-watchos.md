---
task_id: 02
plan_id: PLAN_multi-substitution-watchos
plan_file: ./PLAN_multi-substitution-watchos.md
title: Implement watchOS multi-substitution hub and spoke flows
phase: watchOS UI
---

## Supersession Note
- Superseded on 2026-03-25 by `PLAN_schedule-match-sheets` for newly authored scheduled matches.
- Current intended precedence is:
  - ready schedule-owned match sheets first
  - numeric/manual fallback when match-sheet data exists but is not watch-ready
  - synced library roster lookup only for legacy schedules with no match-sheet fields

- [x] Replace the old single `player off -> player on` watch substitution flow with a hub showing `Player(s) off`, `Player(s) on`, and `Done`.
- [x] Allow either side to be entered first and disable `Done` until both sides have the same non-zero count.
- [x] Use frozen match-sheet lineup selection when both sides are watch-ready, and retain roster multi-select only for legacy no-sheet schedules.
- [x] Add numeric batch collection fallback with add/edit/remove affordances when explicit match-sheet data is incomplete or no roster source is available.
- [x] Remove the watch UI dependence on `substitutionOrderPlayerOffFirst`.
