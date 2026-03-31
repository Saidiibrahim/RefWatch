---
task_id: TASK_03_schedule-match-sheets
plan_id: PLAN_schedule-match-sheets
plan_file: ./PLAN_schedule-match-sheets.md
title: Implement iPhone editing and watch consumption for schedule-owned match sheets
phase: Phase 3 - Product implementation
---

## Supersession Note
- This task records the original schedule-owned match-sheet rollout. Current user-facing behavior is superseded by `docs/exec-plans/active/match-sheet-import/PLAN_match-sheet-import.md`.
- The current contract hides iPhone `draft` / `ready` state from users, removes source-team selection and library-team reseeding from iPhone editing, allows optional Teams library/catalog name autofill from the app’s existing team-selection flow, and uses optional per-side save behavior plus side-specific watch fallback.

- [x] Add iPhone `Home Match Sheet` / `Away Match Sheet` sections and editor flows.
- [x] Keep iPhone match-sheet authoring schedule-owned and free-text, allowing manual/ad hoc participants plus preserved imported provenance without library-team reseeding, while permitting optional Teams library/catalog autofill of the visible home/away names through the app’s existing team-selection flow.
- [x] Freeze selected sheets into live matches before kickoff.
- [x] Update watch substitution/player-selection to use ready frozen sheets first and explicit safe fallback second.
