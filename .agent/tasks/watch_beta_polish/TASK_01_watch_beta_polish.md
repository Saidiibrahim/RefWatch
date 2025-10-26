---
task_id: 01
plan_id: watch_beta_polish_readiness
plan_file: ../../plans/watch_beta_polish/PLAN.md
title: Restore regulation match durations in picker
phase: Phase 1 – Match Configuration
created: 2025-02-15
status: Ready
priority: High
estimated_minutes: 45
dependencies: []
tags: [watchos, match, settings, ux]
---

# Task 01: Restore Regulation Match Durations in Picker

## Objective

Ensure referees can pick standard 90-minute matches plus common youth/extra formats from the duration picker in `MatchSettingsListView`, preventing awkward defaults when creating or resuming games.

## Context

- `MatchSettingsListView` currently feeds the duration picker with `[40, 45, 50]`. The canonical 90-minute option vanished, and shorter youth presets (e.g., 30/35) are missing.
- `MatchViewModel.matchDuration` expects minutes before converting to seconds. Updating the array keeps persistence logic intact.
- Consider localization: labels are formatted with `"\(value) min"`, so no extra string files required as long as the unit suffix remains consistent.

## Steps

1. Update the `values` array passed to `SettingPickerView` with a curated list (e.g., `[30, 35, 40, 45, 50, 60, 70, 80, 90]`) ordered ascending.
2. Confirm the default selection still respects the model’s existing value (should be 90 after change).
3. Run affected previews/tests to verify no type mismatches or layout regressions.
4. Document the chosen durations in task notes for future refinement (e.g., schedule-driven lists).

## Acceptance Criteria

- Picker shows the new duration options, including 90 minutes.
- Selecting each value updates `matchViewModel.matchDuration` correctly.
- No regressions in Match setup previews or tests.

## Notes

- Longer-term improvement: hydrate the list from aggregate schedule metadata, but that requires watch/iPhone contract updates and is out-of-scope here.
