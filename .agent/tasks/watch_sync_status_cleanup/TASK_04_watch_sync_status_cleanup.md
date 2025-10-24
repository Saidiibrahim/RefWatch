---
task_id: 04
plan_id: PLAN_watch_sync_status_cleanup
plan_file: ../../plans/watch_sync_status_cleanup/PLAN_watch_sync_status_cleanup.md
title: Add regression tests for saved-match filtering, schedule status updates, and timer labels
phase: Phase 4 - Regression Coverage
---

## Objective
Lock in the fixes with automated coverage so future sync or UI changes cannot silently reintroduce the discovered regressions.

## Scope

### Critical Regression Tests (must pass before merge)

**1. Status Decoder Tests** (foundation for all other work)
- Assert `ScheduledMatch.Status(fromDatabase:)` correctly maps "in_progress" → `.inProgress`
- Assert all four database statuses decode correctly (`scheduled`, `in_progress`, `completed`, `canceled`)
- Assert unknown values fall back to `.scheduled` with debug telemetry

**2. Watch Saved Match Filtering Tests**
- Assert `MatchViewModel.savedMatches` excludes `.completed` and `.canceled` schedules
- Assert `MatchViewModel.savedMatches` retains `.inProgress` schedules in the list
- Assert `finalizeMatch()` removes the active match from `localSavedMatches`
- Assert filtering tolerates nil/missing `statusRaw` values (legacy payload compatibility)

**3. iOS Schedule Persistence Tests**
- Assert `IOSConnectivitySyncClient.persist()` marks the matching schedule as `.completed`
- Assert schedule updates execute on the main actor (no threading violations)
- Assert telemetry fires when completed match has no corresponding schedule record
- Assert missing-schedule scenario doesn't throw errors (graceful degradation)

**4. iOS UI Filtering Tests**
- Assert `MatchesTabView.handleScheduleUpdate` excludes `.completed` from "Upcoming"
- Assert `.inProgress` schedules remain in "Today" list during active matches
- Assert `.canceled` schedules are excluded from both "Today" and "Upcoming"

**5. Timer Team Name Tests**
- Assert `TimerView.scoreDisplay` uses `homeTeamDisplayName`/`awayTeamDisplayName` after `startMatch()`
- Assert timer does NOT revert to fallback `homeTeam`/`awayTeam` properties mid-match

**6. Live Activity Team Name Tests**
- Assert `LiveActivityStatePublisher.deriveState` uses `currentMatch` team names for `homeAbbr`/`awayAbbr`
- Assert live activity state does NOT use fallback `match.homeTeam`/`match.awayTeam` after kickoff

## Deliverables

### New Test Files

**RefZoneiOSTests**:
1. `ScheduledMatchStatusDecoderTests.swift` (new file)
   - `test_statusDecoding_mapsSnakeCaseToCamelCase()`
   - `test_statusDecoding_fallsBackToScheduledForUnknown()`

2. `IOSConnectivitySyncClient_ScheduleUpdateTests.swift` (new file)
   - `test_persistCompletedMatch_marksScheduleCompleted()`
   - `test_persistCompletedMatch_runsOnMainActor()`
   - `test_persistCompletedMatch_emitsTelemetryIfScheduleMissing()`

3. `MatchesTabView_FilterTests.swift` (new file or extend existing)
   - `test_handleScheduleUpdate_excludesCompletedFromUpcoming()`
   - `test_handleScheduleUpdate_retainsInProgressInToday()`
   - `test_handleScheduleUpdate_excludesCanceledFromBoth()`

### Extended Test Files

**RefZoneWatchOSTests**:
4. `MatchViewModel_SavedMatchFilteringTests.swift` (extend or create in existing suite)
   - `test_updateLibrary_excludesCompletedSchedules()`
   - `test_updateLibrary_retainsInProgressSchedules()`
   - `test_finalizeMatch_prunesLocalSavedMatch()`
   - `test_updateLibrary_toleratesNilStatusRaw()`

5. `TimerView_TeamNameTests.swift` (new file)
   - `test_scoreDisplay_usesCurrentMatchTeamNames()`

6. `LiveActivityStatePublisher_TeamNameTests.swift` (new file)
   - `test_deriveState_usesCurrentMatchTeamNames()`

### Documentation
- Test plan summary documenting which tests guard against which regressions
- Mapping of test cases back to issues in PLAN_watch_sync_status_cleanup.md
