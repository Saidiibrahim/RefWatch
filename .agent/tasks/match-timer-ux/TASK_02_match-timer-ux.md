---
task_id: 02
plan_id: PLAN_match-timer-ux
plan_file: ../../plans/PLAN_match-timer-ux.md
title: Refactor event flow routing back to timer
phase: Implementation
---

- [ ] Add completion closures to event flow views; invoke from MatchTimerView sheets.
- [ ] Move sheet presentations from MatchActionsSheet to MatchTimerView; keep actions sheet only as launcher.
- [ ] Ensure saving any event dismisses to timer and refreshes list.
