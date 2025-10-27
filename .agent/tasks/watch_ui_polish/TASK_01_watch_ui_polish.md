---
task_id: 01
plan_id: watch_ui_polish_beta_readiness
plan_file: ../../plans/watch_ui_polish/PLAN_watch_ui_polish.md
title: Retire placeholder "Choose colours" action
phase: Phase 1 – Match options polish
created: 2025-10-26
updated: 2025-10-26
status: Pending
priority: High
estimated_minutes: 45
dependencies: []
tags: [watchos, ui, polish]
---

# Task 01: Retire Placeholder "Choose colours" Action

## Objective
Ensure the in-match options sheet only exposes actionable controls by removing the unfinished "Choose colours" row and replacing it with static roadmap guidance for testers.

## Context
- `RefZoneWatchOS/Features/Timer/Views/MatchOptionsView.swift` currently renders an `ActionButton` that toggles `showingColorPicker` and pops an alert stating the feature is coming soon.
- The surrounding section uses themed `ActionButton` rows, so removing a button entirely can collapse spacing unless we substitute a non-interactive `ThemeCardContainer`.
- The `showingColorPicker` state becomes unused once the action is removed and should be cleaned up to avoid dead code.

## Steps
1. Replace the "Choose colours" `ActionButton` with a non-interactive card (e.g., `ThemeCardContainer`) that briefly explains colour customization is planned, ensuring list spacing remains aligned with the other rows.
2. Remove the associated alert state (`showingColorPicker`) and alert modifier since testers should no longer see the placeholder dialog.
3. Confirm the remaining options ("Home", "Reset match", "Abandon match") retain their styling and identifiers.

## Acceptance Criteria
- The options list shows no tappable "Choose colours" action.
- Testers see a brief static message acknowledging colour customization is forthcoming.
- No unused state or alert code remains for the feature gate.

## Verification
- Inspect `MatchOptionsView` in SwiftUI previews and the watch simulator to confirm spacing and styling remain consistent and no runtime warnings appear.
