---
task_id: 03
plan_id: PLAN_watch_sync_status_cleanup
plan_file: ../../plans/watch_sync_status_cleanup/PLAN_watch_sync_status_cleanup.md
title: Keep timer score displays bound to the active match’s team names
phase: Phase 3 - Watch Timer UX
---

## Objective
Prevent the watch timer from reverting to default team names once the match clock starts by consistently reading from the active `currentMatch`.

## Scope
- Update `TimerView.scoreDisplay` (RefZoneWatchOS/Features/Timer/Views/TimerView.swift:160-165) to pass `homeTeamDisplayName` / `awayTeamDisplayName` instead of fallback `homeTeam` / `awayTeam` properties to `ScoreDisplayView`.
- Update `LiveActivityStatePublisher.deriveState` (RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityStatePublisher.swift:60-61) to use `currentMatch` team names for `homeAbbr` and `awayAbbr` instead of the fallback `match.homeTeam` / `match.awayTeam`.
- Audit other timer-era UI (confirmation overlays and complication publishers, if present) to ensure none rely on the fallback `homeTeam` / `awayTeam` properties after kickoff.
- Adjust `ScoreDisplayView` previews if necessary to reflect the new data flow.

## Deliverables
- Updated `TimerView` passing display names to `ScoreDisplayView`
- Updated `LiveActivityStatePublisher` using `currentMatch` for team abbreviations in live activity state
- Audit report confirming no other publishers access fallback team properties post-kickoff
- Unit test ensuring timer renders selected names after `startMatch()` when a saved match is loaded
- Unit test ensuring live activity state uses selected names instead of fallback defaults
