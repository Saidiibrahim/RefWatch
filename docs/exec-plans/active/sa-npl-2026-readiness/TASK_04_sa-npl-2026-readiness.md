---
task_id: 04
plan_id: PLAN_sa-npl-2026-readiness
plan_file: ./PLAN_sa-npl-2026-readiness.md
title: Validate tests and handoff verification package
phase: Phase 4 - Validation & Handoff
---

## Objective
Run tests for changed areas and provide MCP SQL verification checklist for next coding agent.

## Status
Completed (with deferred MCP verification)

## Notes
- Focused test slices for card metadata and SA misconduct template were executed and passing.
- iOS app target build was executed and passing.
- `swift test --package-path RefWatchCore` currently fails in this workspace as of 2026-02-28 in:
  - `AggregateSyncPayloadTests.testDeltaPayloadRoundTrip`
  - `ExtraTimeAndPenaltiesTests.test_penalty_attempt_logging_and_tallies`
  - `MatchViewModel_EventsAndStoppageTests.test_end_current_period_records_period_end_event`
- Full Supabase verification remains deferred to next coding agent due unavailable `refwatch-database` MCP access in this session.

## Evidence
- `swift test --package-path RefWatchCore --filter CardDetailsTests` -> pass
- `swift test --package-path RefWatchCore --filter MisconductTemplateCatalogTests` -> pass
- `swift test --package-path RefWatchCore` -> fail (3 current failures listed above)
- `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'generic/platform=iOS Simulator' build` -> pass
