---
task_id: 01
plan_id: PLAN_match-sheet-import
plan_file: ./PLAN_match-sheet-import.md
title: Supersede the old match-sheet contract in docs and plans
phase: Docs and intent
---

- [x] Rewrite the scheduled match-sheet spec around optional per-side sheets and concrete watch fallback behavior.
- [x] Update iOS and watchOS architecture docs so they no longer depend on a two-sided `watch-ready` gate.
- [x] Update the match-timer spec so substitutions, goals, and cards all describe side-specific saved-sheet usage.
- [x] Re-scope the active `match-sheet-import` plan from preview-only work to the broader simplified optional-sheet implementation.
- [x] Add a superseding note to the older historical schedule-match-sheets plan.
