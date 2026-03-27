# PLAN_multi-substitution-watchos-speed-polish

## Purpose / Big Picture
Document the follow-on watchOS substitution UX polish that makes multi-substitution entry faster for referees. This workstream captures the approved behavior for the speed pass only; it does not reopen participant-source precedence, persistence schema, or match-sheet ownership decisions.

Approved behavior to document:
- remove the top substitutions summary card from the hub
- show shirt numbers only in the hub subtitles
- let multi-pair batches skip confirmation and save immediately
- keep `Confirm Subs` in place as single-pair confirmation behavior
- keep the single-pair confirmation surface to one number-only substitution card with no separate shared match time card
- let manual keypad backspace pop the most recently committed number when the input buffer is empty

## Context and Orientation
- Watch substitution UX: `RefWatchWatchOS/Features/Events/Views/SubstitutionFlow.swift`
- Shared keypad component: `RefWatchWatchOS/Core/Components/Input/NumericKeypad.swift`
- Watch settings copy: `RefWatchWatchOS/Features/Settings/Views/SettingsScreen.swift`
- Watch tests: `RefWatchWatchOSTests/SubstitutionFlowSupportTests.swift`
- Product intent baseline: `docs/product-specs/match-timer.md`
- watchOS architecture baseline: `docs/design-docs/architecture/watchos.md`
- Current historical implementation context: `docs/exec-plans/active/multi-substitution-watchos/PLAN_multi-substitution-watchos.md`

## Plan of Work
1. Simplify the watch substitution hub so referees see only the two spoke rows and `Done`, with number-only summaries in the hub and names retained only inside selection lists.
2. Simplify manual numeric entry so the spoke is keypad-first, with stack-style undo on backspace when the input buffer is empty.
3. Keep single-pair confirmation behavior behind `Confirm Subs`, but bypass confirmation for multi-pair batches.
4. Add focused watch-side coverage for summary formatting, duplicate rejection, manual backspace undo, and the single-pair-vs-batch confirmation rule.
5. Record the final behavior in product/architecture docs and track the pass separately from the historical multi-substitution plan.

## Concrete Steps
- (TASK_01_multi-substitution-watchos-speed-polish.md) Refresh product/architecture docs and register the follow-on plan in the exec-plans index.
- (TASK_02_multi-substitution-watchos-speed-polish.md) Implement the watch UI, keypad, settings-copy, and test updates for the speed polish.
- (TASK_03_multi-substitution-watchos-speed-polish.md) Run validation and capture results, risks, and evidence.

## Progress
- [x] TASK_01_multi-substitution-watchos-speed-polish.md
- [x] TASK_02_multi-substitution-watchos-speed-polish.md
- [ ] TASK_03_multi-substitution-watchos-speed-polish.md

## Surprises & Discoveries
- The smallest viable test seam was not a new view model; exposing tiny pure helpers from the existing watch view files was enough to cover summary formatting, confirmation gating, and manual undo behavior.
- Once the top summary card was removed, the shared `NavigationRowLabel` subtitle became the only place to review multi-number selections on the hub. The label needed two-line wrapping so batches would remain legible on smaller watch layouts.

## Decision Log
- Decision: treat multi-pair confirmation bypass as the approved watchOS speed path.
- Rationale: referees need the fastest possible restart after entering several substitutions at once.
- Date/Author: 2026-03-26 / Codex

- Decision: document `Confirm Subs` as single-pair-only in practice, not as the default behavior for batch saves.
- Rationale: preserves the existing setting while removing unnecessary friction from multi-pair batches.
- Date/Author: 2026-03-26 / Codex

- Decision: keep the single-pair confirmation surface aligned with the speed-first watch contract by showing one number-only substitution card and removing the separate shared match time card.
- Rationale: preserves the quick verification affordance without reintroducing visual chrome that slows the referee down.
- Date/Author: 2026-03-27 / Codex

- Decision: document keypad backspace as stack-style undo when no partial number is being edited.
- Rationale: lets referees correct manual batches without opening a second edit surface.
- Date/Author: 2026-03-26 / Codex

## Testing Approach
- `swift test --package-path RefWatchCore` to confirm the known package baseline has not changed.
- `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`
- Manual physical-watch follow-up on Apple Watch Series 9 (45mm) for batch save speed, manual backspace undo, and single-pair confirmation behavior.

## Constraints & Considerations
- Keep the follow-on scope limited to watch UX, watch-local helper logic, tests, and docs.
- Do not reopen persistence, backend, or schema work in this pass.
- Preserve the historical `multi-substitution-watchos` plan as implementation context, not the active source of truth for the speed polish.

## Outcomes & Retrospective
- Implemented the approved watchOS speed polish in the hub, manual numeric spoke, shared keypad, settings copy, focused watch tests, previews, and product/architecture docs.
- Added a low-risk follow-on polish to let navigation-row subtitles wrap to two lines, preventing multi-number substitution summaries from truncating on compact watch layouts.
- Extended the follow-on polish so single-pair confirmation now stays speed-first as well: one number-only substitution card, no separate shared match time card, and no changes to the player-selection spokes.
- Validation to date:
  - `git diff --check` passed.
  - `swift test --package-path RefWatchCore` reproduced the existing baseline failures in `AggregateSyncPayloadTests.testDeltaPayloadRoundTrip` and `ExtraTimeAndPenaltiesTests.test_penalty_attempt_logging_and_tallies`; no new package failures appeared.
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -derivedDataPath /tmp/refwatch-multi-sub-speed-polish-build -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build` succeeded after the implementation fixes, with only the pre-existing widget short-version warning.
  - `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -derivedDataPath /tmp/refwatch-multi-sub-speed-polish-test-target -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:'RefWatch Watch AppTests/SubstitutionFlowSupportTests'` succeeded.
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -derivedDataPath /tmp/refwatch-single-sub-confirm-build -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build` succeeded after the single-pair confirmation simplification, with only the pre-existing widget short-version warning.
  - `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -derivedDataPath /tmp/refwatch-single-sub-confirm-test-target -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:'RefWatch Watch AppTests/SubstitutionFlowSupportTests'` succeeded, including the new number-only confirmation summary checks.
  - The full scheme test under `/tmp/refwatch-multi-sub-speed-polish-test-full` rebuilt the patched watch files and entered simulator execution, but it did not finish within the available validation window; no watch compile failure surfaced before the stall.
- Remaining follow-up:
  - Physical-watch verification on Apple Watch Series 9 (45mm).
  - Decide whether the hanging full-scheme simulator run needs a separate UI-test stabilization pass.
