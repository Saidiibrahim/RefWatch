---
task_id: 01
plan_id: PLAN_watch_sync_status_cleanup
plan_file: ../../plans/watch_sync_status_cleanup/PLAN_watch_sync_status_cleanup.md
title: Restrict watch saved matches to upcoming fixtures and prune local entries on completion
phase: Phase 1 - Watch Saved Match Hygiene
---

## Objective
Keep the watch start flow focused on upcoming fixtures by excluding completed/canceled schedules and removing watch-authored matches once they finish.

## Scope
- Interpret `MatchLibrarySchedule.statusRaw` into `ScheduledMatch.Status`, default unknown or missing values to `.scheduled`, and filter for `.scheduled` / `.inProgress` before populating `librarySavedMatches`, emitting telemetry when fallbacks occur.
- Ensure `refreshSavedMatches()` excludes schedules explicitly marked completed/canceled while preserving legacy entries that rely on the fallback mapping.
- Update `finalizeMatch()` (and related teardown hooks) to remove the active match from `localSavedMatches` prior to resetting state.
- Recompute `savedMatches` after pruning so `SavedMatchesListView` immediately reflects the filtered set.

## Deliverables
- Updated `MatchViewModel` logic with status-aware filtering and local saved match cleanup.
- Unit tests covering both remote schedules and watch-created matches (including nil/unknown status payloads) to guard against regressions.
