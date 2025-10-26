---
task_id: 03
plan_id: watch_beta_polish_readiness
plan_file: ../../plans/watch_beta_polish/PLAN.md
title: Surface real team names in kickoff & goal flows
phase: Phase 3 – Presentation Polish
created: 2025-02-15
updated: 2025-02-15
status: Completed
completed: 2025-02-15
priority: Medium
estimated_minutes: 60
dependencies: [01]
tags: [watchos, ui, accessibility]
---

# Task 03: Surface Real Team Names in Kickoff & Goal Flows

## Objective

Replace placeholder “HOM/AVA” labels with actual team names sourced from `MatchViewModel`, while keeping sensible fallbacks and accessibility labels.

## Context

- `TeamDetailsView` header and `GoalTypeSelectionView` title still use hard-coded abbreviations, even after syncing a real match.
- `MatchViewModel.homeTeamDisplayName` / `awayTeamDisplayName` already expose the correct strings, pulling from aggregate snapshots when available.
- These screens run on very small layouts, so ensure longer names wrap or scale gracefully, particularly on 41mm watches and with large Dynamic Type.

## Steps

1. Update `TeamDetailsView` header to prefer `matchViewModel.homeTeamDisplayName`/`awayTeamDisplayName`, falling back to abbreviations only if the names are empty.
2. Pass the display names into `GoalTypeSelectionView` (via initializer parameters or environment) and reflect them in titles/accessibility labels.
3. Verify the adaptive grid, button labels, and analytics/haptics logic remain intact.
4. Exercise previews with long names to confirm layout adjusts; tweak typography/line limits if necessary.
5. Add accessibility hints ensuring VoiceOver announces the real club names.

## Acceptance Criteria

- Kickoff and goal flows visibly show the selected team names for both sides.
- Layout remains legible across compact/expanded watch layout scales and respects Dynamic Type.
- Accessibility reads the real names and does not regress existing labels.

## Notes

- Consider caching trimmed (max length) variants if we encounter extremely long club strings; otherwise rely on `minimumScaleFactor` adjustments.

## Outcome

- `TeamDetailsView` and `GoalTypeSelectionView` now drive labels from `MatchViewModel` display names with whitespace fallbacks, keeping accessibility labels in sync.
