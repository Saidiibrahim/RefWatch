---
task_id: 02
plan_id: PLAN_watch_sync_status_cleanup
plan_file: ../../plans/watch_sync_status_cleanup/PLAN_watch_sync_status_cleanup.md
title: Propagate completion status to the iOS schedule store and tighten Upcoming filtering
phase: Phase 2 - iOS Schedule Integrity
---

## Objective
Ensure completed fixtures disappear from the iPhone Upcoming/Todays lists by updating schedule persistence and UI filtering when the watch uploads a finished match.

## Scope
- Inject a `ScheduleStoring` dependency into `IOSConnectivitySyncClient` and ensure `persist(_:)` executes on the main actor while marking the matching schedule `.completed`, never deleting rows that other tables reference.
- Add telemetry / a retry hook for cases where the schedule is missing (e.g. user offline) so status updates reconcile later instead of silently failing.
- Update `ConnectivitySyncController` initialisation and any tests/stubs to satisfy the new dependency.
- Refactor `MatchesTabView.handleScheduleUpdate` to exclude `.completed`/`.canceled` schedules from “Today” and “Upcoming” while retaining `.inProgress`.
- Extract the filtering logic into a helper (struct/function) that can be unit tested in `RefZoneiOSTests`.

## Deliverables
- Revised connectivity client and controller wiring with schedule status updates flowing to storage.
- Updated matches UI with status-aware filtering.
- Unit tests validating both the schedule persistence update (including missing-schedule fallbacks) and the upcoming/today filter helper.
