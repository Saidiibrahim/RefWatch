# PLAN_multi-substitution-watchos

## Purpose / Big Picture
Allow referees to record multiple substitutions on watchOS in one flow so each pair is saved at the same match time, while making roster-based selection reliable for iPhone-created matches.

## Context and Orientation
- Watch substitution entry starts from `RefWatchWatchOS/Features/MatchSetup/Views/MatchSetupView.swift`.
- The watch substitution UI lives in `RefWatchWatchOS/Features/Events/Views/SubstitutionFlow.swift`.
- Shared event persistence lives in `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift`.
- Watch/iPhone roster propagation depends on:
  - `RefWatchiOS/Core/Platform/Connectivity/AggregateSnapshotBuilder.swift`
  - `RefWatchiOS/Core/Persistence/SwiftData/SwiftDataScheduleStore.swift`
  - `RefWatchWatchOS/Core/Persistence/SwiftData/WatchAggregateDataStores.swift`
  - `RefWatchWatchOS/Core/Platform/Connectivity/WatchAggregateLibraryStore+MatchLibrary.swift`
- Product and architecture baselines: `docs/product-specs/match-timer.md`, `docs/design-docs/architecture/watchos.md`.

## Plan of Work
1. Propagate scheduled-match team IDs through iPhone persistence, aggregate sync payloads, watch persistence, and watch library hydration so roster lookup prefers IDs.
2. Replace the single-substitution watch flow with a hub-and-spoke multi-substitution flow that supports roster multi-select and keypad collection fallback.
3. Add shared batch-recording semantics so all saved substitutions in a batch share one captured event-time snapshot.
4. Validate shared tests, watch build/test, and document the resulting product and architecture behavior.

## Concrete Steps
- (TASK_01_multi-substitution-watchos.md) Propagate team IDs and roster resolution inputs to the watch.
- (TASK_02_multi-substitution-watchos.md) Implement the watch hub/spoke batch substitution experience.
- (TASK_03_multi-substitution-watchos.md) Add shared batch-event semantics plus substitution display/confirmation updates.
- (TASK_04_multi-substitution-watchos.md) Validate builds/tests and record documentation/evidence.

## Progress
- [x] TASK_01_multi-substitution-watchos.md
- [x] TASK_02_multi-substitution-watchos.md
- [x] TASK_03_multi-substitution-watchos.md
- [ ] TASK_04_multi-substitution-watchos.md

## Surprises & Discoveries
- Scheduled matches created on iPhone did not consistently preserve chosen team IDs all the way through local schedule persistence and aggregate sync, which made watch roster resolution fall back to names too often.
- The existing watch keypad component needed an accessory action path for multi-number collection; bolting batch collection on top of the old single-submit API was not enough.

## Decision Log
- Decision: roster-based substitution entry prefers synced team IDs and only falls back to exact team-name matching for compatibility with older local data.
- Rationale: team IDs make iPhone-created team sheets usable on watch without depending on display-name matching.
- Date/Author: 2026-03-24 / Codex
- Decision: save batch substitutions as normal individual substitution events captured from one frozen match-time snapshot.
- Rationale: this preserves existing history/sync/undo behavior while meeting the referee need for shared match time.
- Date/Author: 2026-03-24 / Codex
- Decision: remove the watch UI effect of `substitutionOrderPlayerOffFirst` and let referees enter off/on sides in any order from the hub.
- Rationale: batch entry requires explicit off/on spokes rather than a forced sequential starting side.
- Date/Author: 2026-03-24 / Codex

## Testing Approach
- Shared/core:
  - `swift test --package-path RefWatchCore`
- watchOS:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
  - `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`
- Manual:
  - verify roster multi-select from both home and away team surfaces
  - verify keypad collection add/edit/remove fallback when no roster exists
  - verify `Done` stays disabled until off/on counts match
  - verify confirmation summarizes ordered pairs when `Confirm Subs` is enabled

## Constraints & Considerations
- Keep watch navigation on the parent `NavigationStack`; do not reintroduce nested-stack behavior that regresses the existing substitution-navigation fix.
- Preserve existing substitution event storage and undo semantics.
- Treat Apple Watch Series 9 (45mm) as the primary validation target.

## Outcomes & Retrospective
- In progress.
