---
task_id: 04
plan_id: PLAN_multi-substitution-watchos
plan_file: ./PLAN_multi-substitution-watchos.md
title: Validate watch build/test outcomes and capture documentation
phase: Validation
---

- [x] Run `swift test --package-path RefWatchCore`.
- [x] Build `RefWatch Watch App` for Apple Watch Series 9 (45mm) simulator.
- [ ] Run `RefWatch Watch App` simulator tests.
- [x] Update `docs/product-specs/match-timer.md` with multi-substitution behavior.
- [x] Update `docs/design-docs/architecture/watchos.md` with watch substitution flow/state ownership details.
- [x] Record follow-up issues or residual risks discovered during validation.

## Validation Notes
- `swift test --package-path RefWatchCore` still reports unrelated baseline failures in `AggregateSyncPayloadTests.testDeltaPayloadRoundTrip` and `ExtraTimeAndPenaltiesTests.test_penalty_attempt_logging_and_tallies`.
- Targeted core verification passed for batch substitution snapshotting and schedule team-ID propagation.
- `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build` passed after fixing a `NumericKeypad` preview signature mismatch.
- Watch/iOS simulator test runs for the new sync coverage are still compiling dependencies and were not complete at the time this task file was updated.
- Existing on-disk SwiftData migration behavior for the new persisted `homeTeamId` and `awayTeamId` fields still needs explicit upgrade validation against older stores.
