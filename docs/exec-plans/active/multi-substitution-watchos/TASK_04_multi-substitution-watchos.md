---
task_id: 04
plan_id: PLAN_multi-substitution-watchos
plan_file: ./PLAN_multi-substitution-watchos.md
title: Validate watch build/test outcomes and capture documentation
phase: Validation
---

## Supersession Note
- The validation evidence below remains historically true for the roster-based phase, but it is no longer the desired product end state for newly authored scheduled matches.
- `docs/exec-plans/active/match-sheet-import/PLAN_match-sheet-import.md` is now the active source of truth for participant resolution, optional-sheet save behavior, and side-specific fallback rules.

- [x] Run `swift test --package-path RefWatchCore`.
- [x] Build `RefWatch Watch App` for Apple Watch Series 9 (45mm) simulator.
- [ ] Run `RefWatch Watch App` simulator tests.
- [x] Record the historical roster-based multi-substitution doc updates in `docs/product-specs/match-timer.md`.
- [x] Record the historical roster-based watch flow notes in `docs/design-docs/architecture/watchos.md`.
- [x] Record follow-up issues or residual risks discovered during validation.

## Validation Notes
- `swift test --package-path RefWatchCore` still reports unrelated baseline failures in `AggregateSyncPayloadTests.testDeltaPayloadRoundTrip` and `ExtraTimeAndPenaltiesTests.test_penalty_attempt_logging_and_tallies`.
- Targeted core verification passed for batch substitution snapshotting and schedule team-ID propagation.
- `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build` passed after fixing a `NumericKeypad` preview signature mismatch.
- Watch/iOS simulator test runs for the new sync coverage are still compiling dependencies and were not complete at the time this task file was updated.
- Existing on-disk SwiftData migration behavior for the new persisted `homeTeamId` and `awayTeamId` fields still needs explicit upgrade validation against older stores.
- Superseded participant precedence for newly authored schedules is now `ready frozen match sheets -> manual/numeric for explicit incomplete sheets -> roster lookup only for legacy no-sheet schedules`.
- Current product/source-of-truth docs for substitution participant precedence now live under `docs/exec-plans/active/match-sheet-import/PLAN_match-sheet-import.md` and `docs/product-specs/scheduled-match-sheets.md`.
