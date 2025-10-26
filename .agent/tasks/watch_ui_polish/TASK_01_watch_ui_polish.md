---
task_id: 01
plan_id: PLAN_watch_ui_polish
plan_file: ../../plans/watch_ui_polish/PLAN_watch_ui_polish.md
title: Remove or gate the "Choose colours" match option
phase: Phase 1 - Match options polish
---

## Goal
Ensure the match options sheet only exposes actionable items to early testers by hiding or disabling the unfinished "Choose colours" row.

## Steps
- Inspect `MatchOptionsView` to confirm available context for feature gating (e.g., flags or build config).
- Decide between removing the row entirely or converting it into static helper text; implement the chosen approach without breaking layout spacing.
- Update any related alerts or state to reflect the change.
- Verify via SwiftUI preview or simulator that the section spacing remains consistent.

## Verification
- `MatchOptionsView` previews render without the misleading action and no runtime warnings appear in Xcode.
