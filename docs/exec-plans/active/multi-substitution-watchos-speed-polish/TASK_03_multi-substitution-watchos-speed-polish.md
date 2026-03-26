---
task_id: 03
plan_id: PLAN_multi-substitution-watchos-speed-polish
plan_file: ./PLAN_multi-substitution-watchos-speed-polish.md
title: Validate the speed polish and record evidence
phase: Validation
---

- [x] Run `git diff --check`.
- [x] Run `swift test --package-path RefWatchCore` and classify any failures as baseline vs regression.
- [x] Run `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`.
- [ ] Run `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`.
- [ ] Record physical-watch follow-up items that still require Apple Watch Series 9 (45mm) verification.

Validation notes:
- `swift test --package-path RefWatchCore` reproduced the existing baseline failures in `AggregateSyncPayloadTests.testDeltaPayloadRoundTrip` and `ExtraTimeAndPenaltiesTests.test_penalty_attempt_logging_and_tallies`; no new failures were introduced by this workstream.
- `xcodebuild ... build` succeeded using `/tmp/refwatch-multi-sub-speed-polish-build`, with only the pre-existing widget short-version warning.
- Targeted watch tests passed using `/tmp/refwatch-multi-sub-speed-polish-test-target`:
  - `SubstitutionFlowSupportTests/testSelectionSummary_whenEmpty_returnsDefaultCopy()`
  - `SubstitutionFlowSupportTests/testSelectionSummary_whenSelectionsExist_returnsCommaSeparatedNumbersOnly()`
  - `SubstitutionFlowSupportTests/testSelectionSummary_whenNumberMissing_usesQuestionMark()`
  - `SubstitutionFlowSupportTests/testAppendManualSelection_whenUnique_appendsInOrder()`
  - `SubstitutionFlowSupportTests/testAppendManualSelection_whenDuplicate_rejectsNumber()`
  - `SubstitutionFlowSupportTests/testRemoveMostRecentSelection_popsLatestCommittedNumber()`
  - `SubstitutionFlowSupportTests/testRemoveMostRecentSelection_canRepeatUntilEmpty()`
  - `SubstitutionFlowSupportTests/testCanSubmit_requiresEqualNonZeroCounts()`
  - `SubstitutionFlowSupportTests/testShouldRequireConfirmation_onlyForSinglePairWhenEnabled()`
  - `SubstitutionFlowSupportTests/testNumericKeypadBackspace_removesTypedDigitsUntilEmpty()`
- The full scheme test under `/tmp/refwatch-multi-sub-speed-polish-test-full` rebuilt the patched watch code and entered simulator execution, but did not complete within the available validation window. No watch compile failure surfaced before the stall; the only runtime noise observed was repeated `DebuggerLLDB.DebuggerVersionStore.StoreError` logging from Xcode.
