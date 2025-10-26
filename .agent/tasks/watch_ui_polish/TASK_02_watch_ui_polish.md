---
task_id: 02
plan_id: PLAN_watch_ui_polish
plan_file: ../../plans/watch_ui_polish/PLAN_watch_ui_polish.md
title: Improve team headers and guidance in TeamDetailsView
phase: Phase 1 - Team setup clarity
---

## Goal
Display the configured team names and add descriptive guidance to the team detail tabs so referees instantly know which side they are editing.

## Steps
- Replace the `"HOM"`/`"AWA"` header text in `TeamDetailsView` with the dynamic team name (`matchViewModel.homeTeamDisplayName` / `awayTeamDisplayName`).
- Add a short caption under the header (e.g., "Manage home events") that scales for compact layouts but remains legible.
- Ensure text truncation/scale factors keep long team names readable on 41mm watches.
- Update accessibility labels to announce the full team name and role.
- Re-run previews to confirm layout stability across compact and expanded watch sizes.

## Verification
- `TeamDetailsView` previews show the real team names with supportive copy and no layout clipping on compact screens.
