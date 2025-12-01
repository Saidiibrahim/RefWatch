---
task_id: 03
plan_id: PLAN_match-timer-ux
plan_file: ../../plans/PLAN_match-timer-ux.md
title: Redesign timeline UI for long logs
phase: Implementation
---

- [ ] Replace fixed-height List with ScrollViewReader + LazyVStack and auto-scroll to latest.
- [ ] Remove 25-event cap; add empty-state hint and period grouping if feasible.
- [ ] Verify layout works with safe areas and large content.
