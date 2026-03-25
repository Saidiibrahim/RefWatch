# PLAN_schedule-match-sheets

## Purpose / Big Picture
Implement schedule-owned home and away match sheets for upcoming matches on iPhone, then make watchOS live-match player selection consume those frozen schedule snapshots instead of mutable library rosters.

## Context and Orientation
- iPhone schedule editing currently lives in `RefWatchiOS/Features/Matches/Views/UpcomingMatchEditorView.swift`.
- Schedule persistence/sync currently flows through:
  - `RefWatchiOS/Core/Models/ScheduledMatch.swift`
  - `RefWatchiOS/Core/Persistence/SwiftData/ScheduledMatchRecord.swift`
  - `RefWatchiOS/Core/Platform/Supabase/SupabaseScheduleAPI.swift`
  - `RefWatchiOS/Core/Platform/Connectivity/AggregateSnapshotBuilder.swift`
- Watch schedule consumption currently flows through:
  - `RefWatchCore/Sources/RefWatchCore/Domain/MatchLibraryModels.swift`
  - `RefWatchWatchOS/Core/Persistence/SwiftData/WatchAggregateModels.swift`
  - `RefWatchWatchOS/Core/Platform/Connectivity/WatchAggregateLibraryStore+MatchLibrary.swift`
  - `RefWatchWatchOS/Features/Events/Views/SubstitutionFlow.swift`
- Shared live-match persistence currently flows through:
  - `RefWatchCore/Sources/RefWatchCore/Domain/Match.swift`
  - `RefWatchCore/Sources/RefWatchCore/Domain/ActiveMatchSessionSnapshot.swift`
  - `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift`

## Plan of Work
1. Define schedule-owned match-sheet product and architecture contracts, and supersede the stale roster-based watch assumption in active docs/plans.
2. Add shared match-sheet models plus live-match freeze/restore support in `RefWatchCore`.
3. Extend iPhone schedule persistence, Supabase sync, and aggregate snapshot transport with optional home/away match sheets.
4. Add iPhone schedule editor UI for creating, editing, and summarizing match sheets per side.
5. Update watch aggregate hydration and substitution/player-selection flows to prefer ready frozen sheets with explicit safe fallback behavior.
6. Add regression coverage and build/test validation for iPhone, shared core, and watch.

## Concrete Steps
- (TASK_01_schedule-match-sheets.md) Add docs/spec/plan artifacts and lock readiness/fallback rules.
- (TASK_02_schedule-match-sheets.md) Add shared models plus iPhone/watch persistence and sync transport.
- (TASK_03_schedule-match-sheets.md) Implement iPhone match-sheet editing and watch consumption.
- (TASK_04_schedule-match-sheets.md) Validate tests/builds and record outcomes.

## Progress
- [x] TASK_01_schedule-match-sheets.md
- [x] TASK_02_schedule-match-sheets.md
- [x] TASK_03_schedule-match-sheets.md
- [x] TASK_04_schedule-match-sheets.md

## Surprises & Discoveries
- The active multi-substitution workstream still treats roster lookup via team IDs as the intended end state, so this plan must explicitly supersede that assumption rather than silently diverging.
- Current live-match persistence freezes only schedule/team identity, not participant snapshots, so kickoff and restore currently have no way to preserve official participants independently of library changes.
- Newly authored schedules need explicit draft match-sheet shells persisted on save, otherwise watch fallback cannot distinguish legacy no-sheet schedules from incomplete new schedules.
- Xcode simulator validation required disabling code signing and isolating DerivedData paths to avoid unrelated build-database lock noise during parallel validation.
- Review follow-up confirmed two implementation gaps after the initial rollout:
  - the editor could overwrite preserved `sourceTeamName` with the fixture fallback when the original source team no longer existed locally
  - new ad hoc player/staff/member entries used `Int.max` sort orders, so authored order was not explicitly stable on save
- Follow-up validation exposed one unrelated iPhone compile issue outside the match-sheet contract:
  - `SupabaseClientProvider.upsertRows` used a nested generic wrapper type that this Xcode toolchain rejected during iOS target compilation
- Validation evidence moved after the follow-up pass:
  - the targeted `swift test --package-path RefWatchCore --filter 'ScheduledMatchSheetTests|MatchViewModelScheduleStatusTests|ActiveMatchSessionRestoreTests/test_restoreRoundTrip_preservesFrozenMatchSheets|MatchViewModel_LibraryIntegrationTests/testUpdateLibraryPropagatesScheduledMatchSheetsToSavedMatch|AggregateSyncPayloadTests/testSnapshotRoundTrip'` suite now passes
  - the watch simulator build now passes on the primary target
  - the first targeted iPhone test rerun failed on the nested generic wrapper compile issue, which is now fixed by moving the wrapper to file scope
  - post-fix iPhone simulator test/build reruns progressed well past the earlier compile blocker but did not reach a final simulator result within this validation window
  - direct watch-UI branch coverage for `.frozenSheet` / `.manualOnly` / `.legacyLibrary` remains thinner than shared-core precedence coverage because there is no dedicated watch view-test harness in the current target

## Decision Log
- Decision: a scheduled match sheet is a schedule-owned frozen snapshot seeded from a library team but never auto-updated from later library edits.
- Rationale: the library remains reusable source data while the scheduled fixture owns the official participant record.
- Date/Author: 2026-03-25 / Codex
- Decision: newly saved schedules persist explicit draft home/away match-sheet shells even before either side is ready.
- Rationale: this keeps pre-feature legacy schedules distinguishable from schedules authored under the match-sheet model, so legacy library-roster fallback remains safely scoped.
- Date/Author: 2026-03-25 / Codex
- Decision: watch uses scheduled match sheets only when both home and away sheets are `ready`; otherwise it must not silently promote mutable library rosters to official match-sheet status.
- Rationale: the product requires an explicit distinction between frozen official participants and reusable source rosters.
- Date/Author: 2026-03-25 / Codex
- Decision: legacy schedules with no match-sheet fields retain roster lookup only as backward-compatibility fallback.
- Rationale: existing schedules must continue to work without pretending incomplete new schedules are equivalent to legacy schedules.
- Date/Author: 2026-03-25 / Codex
- Decision: when starting from a scheduled fixture, match setup preserves the schedule's team identity; referees must edit the schedule first if they need different teams.
- Rationale: frozen home/away sheets must stay aligned with the scheduled fixture they belong to.
- Date/Author: 2026-03-25 / Codex

## Testing Approach
- Shared/core:
  - `swift test --package-path RefWatchCore`
- iPhone:
  - targeted schedule persistence/sync tests if an iOS test target exists
  - `xcodebuild -project RefWatch.xcodeproj -scheme RefWatchiOS -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' build`
- watchOS:
  - `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
  - watch tests covering match-sheet precedence where target coverage exists
- Manual:
  - create/edit both sheets on iPhone
  - verify draft survives relaunch/sync
  - verify ready sheets reach watch and drive substitution choices
  - verify incomplete sheets fall back to numeric/manual entry

## Constraints & Considerations
- Keep migrations additive.
- Keep old schedules without match sheets decoding cleanly across all persistence/sync layers.
- Keep match sheets schedule-owned; do not add persistent match-sheet ownership to library teams.
- Editing match sheets after kickoff is out of scope for v1.
- Add DocC comments for new shared/public types and non-obvious resolver APIs.

## Outcomes & Retrospective
- Implemented schedule-owned `homeMatchSheet` / `awayMatchSheet` snapshots end to end across shared models, iPhone SwiftData, Supabase sync, aggregate transport, watch aggregate storage, and live-match freeze/restore.
- Added iPhone match-sheet editing flows and schedule edit re-entry so referees can create/edit/freeze per-side sheets from upcoming matches.
- Updated watch substitution selection to prefer ready frozen match sheets, fall back to numeric/manual entry when explicit sheets are incomplete, and retain linked-library fallback only for legacy no-sheet schedules.
- Applied Supabase migration `0022_schedule_match_sheets` to the live project and confirmed `public.scheduled_matches` now exposes `home_match_sheet` and `away_match_sheet`.
- Follow-up review fixes keep orphaned schedule sheets from losing preserved source-team provenance and make editor-authored player/staff/member order explicit and stable on save.
- Added targeted iOS regression coverage for preserved source-team metadata, match-sheet persistence round-trips, aggregate hydration, and authored-order normalization.
- Shared-core normalization now reindexes starters, substitutes, staff, and `otherMembers` contiguously so persisted order remains explicit after save/load across storage and sync paths.
- Validation now shows targeted shared-core tests passing, watch simulator build passing, and the previously observed iPhone compile blocker fixed; post-fix simulator reruns remained inconclusive before completion, so only that final iPhone simulator proof is still unresolved.
- Deferred only: direct watch `SubstitutionFlow` UI branch coverage for `.frozenSheet` / `.manualOnly` / `.legacyLibrary`, because shared-core precedence coverage already exists and the watch target does not currently expose a lightweight view-inspection harness.
