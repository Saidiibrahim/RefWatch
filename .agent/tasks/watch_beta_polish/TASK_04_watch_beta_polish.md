---
task_id: 04
plan_id: watch_beta_polish_readiness
plan_file: ../../plans/watch_beta_polish/PLAN.md
title: Polish sync feedback for testers
phase: Phase 4 – Sync Experience
created: 2025-02-15
status: Ready
priority: Medium
estimated_minutes: 90
dependencies: [01, 02, 03]
tags: [watchos, sync, ux]
---

# Task 04: Polish Sync Feedback for Testers

## Objective

Give testers clear feedback when requesting a manual sync and surface a simple “last synced” snapshot on the idle screen/settings without losing engineer-focused diagnostics.

## Context

- `MatchRootView` shows a plain “Sync from iPhone” button with a hidden `ProgressView`; users cannot tell if anything is happening.
- `latestSummary` state is fetched but unused—an opportunity to surface a friendly “Last Match” card alongside sync status.
- `SettingsScreen` displays raw queue counts suited for dev debugging. Early testers need trimmed messaging while leaving a path to the detailed metrics.

## Steps

1. Introduce state in `MatchRootView` to disable the sync button and show an actual spinner while a request is in flight; optionally show success/failure toasts.
2. Populate a lightweight “Last Match” or “Last synced” row using `latestSummary` and/or `aggregateEnvironment.status`, highlighting when data was last refreshed.
3. In `SettingsScreen.syncSection`, replace the raw metrics copy with concise messaging (e.g., reachability + last sync). Move the detailed diagnostics into an expandable disclosure or a secondary screen.
4. Validate that background sync callbacks still work and that the manual action doesn’t spam requests.
5. Update previews/tests to cover the new UI states.

## Acceptance Criteria

- Manual sync control visibly transitions through idle → loading → idle states, with button disabled while pending.
- Idle screen displays a clear “Last synced” or recent match summary without overwhelming detail.
- Settings screen shows plain-language sync status, with diagnostics accessible behind an optional tap.
- No regressions in aggregate sync behavior or Match history loading.

## Notes

- Consider logging sync completion timestamps to `AggregateSyncEnvironment` if not already tracked; otherwise, derive from `status.lastSnapshotGeneratedAt`.
