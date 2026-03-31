# PLAN_schedule-match-sheets

> Superseded for current product behavior on 2026-03-30 by `docs/exec-plans/active/match-sheet-import/PLAN_match-sheet-import.md`.
> This historical plan still describes the original two-sided readiness contract and should be treated as implementation history, not the current user-facing match-sheet contract.

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
- [x] Historical follow-up to remove iPhone scheduled-match editing dependence on `TeamRecord` selection/reseeding was implemented on 2026-03-30, with post-fix targeted unit/build validation complete and the remaining UI gap later classified as a simulator/XCTest harness issue.
- [x] PM follow-up on 2026-03-31 restored optional Teams library/catalog name autofill in `UpcomingMatchEditorView`, but kept scheduled-match editing free-text and schedule-owned with no `TeamRecord` binding or provenance rewrite.

## Surprises & Discoveries
- The active multi-substitution workstream still treats roster lookup via team IDs as the intended end state, so this plan must explicitly supersede that assumption rather than silently diverging.
- Current live-match persistence freezes only schedule/team identity, not participant snapshots, so kickoff and restore currently have no way to preserve official participants independently of library changes.
- Newly authored schedules need explicit draft match-sheet shells persisted on save, otherwise watch fallback cannot distinguish legacy no-sheet schedules from incomplete new schedules.
- Follow-up product direction removed the remaining iPhone editor dependence on live `TeamRecord` selection; the editor must now author schedule-owned manual/ad hoc sheets while preserving any `sourceTeamId` / `sourceTeamName` already stored on imported or older sheets. A later PM follow-up restored Teams library/catalog name autofill only, using the app’s full Teams library/catalog flow without reintroducing `TeamRecord`-driven sheet state or provenance rewrite.
- Xcode simulator validation required disabling code signing and isolating DerivedData paths to avoid unrelated build-database lock noise during parallel validation.
- Review follow-up confirmed two implementation gaps after the initial rollout:
  - the editor could overwrite preserved `sourceTeamName` with the fixture fallback when the original source team no longer existed locally
  - new ad hoc player/staff/member entries used `Int.max` sort orders, so authored order was not explicitly stable on save
- Validation evidence moved after the follow-up pass:
  - `swift test --package-path RefWatchCore --filter ScheduledMatchSheetTests` now passes with the shared resolver fix in place
  - the targeted iPhone regression slice previously passed on `iPhone 15 Pro Max (iOS 17.0.1)` during the decoupling follow-up, including `SwiftDataScheduleStoreTests`, `MatchSheetImportViewModelTests`, and `OpenAIMatchSheetImportServiceTests`
  - the decoupling-specific save-path coverage now proves `UpcomingMatchEditorView.scheduledMatchForSave(...)` preserves existing `homeTeamId` / `awayTeamId`, preserves imported `sourceTeamId` / `sourceTeamName`, and does not mint new team IDs for fresh schedules
  - the post-fix simulator build passed on the same `iPhone 15 Pro Max (iOS 17.0.1)` destination, and the later 2026-03-31 autofill-only follow-up build also still passed there
  - historical note: 2026-03-30 UI reruns stopped at simulator/XCTest issues (`Unknown kAXError value -25218` and related test-harness failures), but that blocker was later cleared by the 2026-03-31 optional-sheet hardening pass, which produced a clean `MatchSheetImportUITests` xcresult at `/tmp/refwatch-optional-sheet-ui-20260331g.xcresult`
  - 2026-03-31 autofill-only follow-up reran the requested iPhone 15 Pro Max target: the build still passed, but the targeted regression slice did not reach product assertions in this wave (`Early unexpected exit ... Test crashed with signal kill before establishing connection` at `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-52-41-+1030.xcresult`, then `FBSOpenApplicationServiceErrorDomain Code=1` / `RequestDenied` during app launch at `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-56-01-+1030.xcresult`)
  - 2026-03-31 UI rerun trace did reach the updated upcoming-match editor and the new `team-name-autofill-home` control, but the class xcresult at `/tmp/refwatch-teamlibrary-name-autofill/Logs/Test/Test-RefWatchiOS-2026.03.31_12-58-17-+1030.xcresult` ended with `Test crashed with signal kill.`
  - direct watch-UI branch coverage for `.frozenSheet` / `.manualOnly` / `.legacyLibrary` remains thinner than shared-core precedence coverage because there is no dedicated watch view-test harness in the current target

## Decision Log
- Decision: a scheduled match sheet is a schedule-owned frozen snapshot seeded from a library team but never auto-updated from later library edits.
- Rationale: the library remains reusable source data while the scheduled fixture owns the official participant record.
- Date/Author: 2026-03-25 / Codex
- Decision: newly saved schedules persist explicit draft home/away match-sheet shells even before either side is ready.
- Rationale: this keeps pre-feature legacy schedules distinguishable from schedules authored under the match-sheet model, so legacy library-roster fallback remains safely scoped.
- Date/Author: 2026-03-25 / Codex
- Decision: watch resolves scheduled match sheets per requested side; a ready saved side takes precedence for that side even if the opposite side is missing or incomplete, while unresolved sides fall back independently.
- Rationale: the product requires frozen official participants whenever a side-specific saved sheet exists, without blocking the whole fixture when only one side has usable saved data.
- Date/Author: 2026-03-25 / Codex
- Decision: legacy schedules with no match-sheet fields retain roster lookup only as backward-compatibility fallback.
- Rationale: existing schedules must continue to work without pretending incomplete new schedules are equivalent to legacy schedules.
- Date/Author: 2026-03-25 / Codex
- Decision: when starting from a scheduled fixture, match setup preserves the schedule's team identity; referees must edit the schedule first if they need different teams.
- Rationale: frozen home/away sheets must stay aligned with the scheduled fixture they belong to.
- Date/Author: 2026-03-25 / Codex
- Decision: iPhone scheduled-match authoring no longer chooses or reseeds from `TeamRecord`; it edits free-text schedule-owned sheets, may autofill the visible name through the app’s Teams library/catalog flow, and only preserves `sourceTeamId` / `sourceTeamName` already present on the sheet.
- Rationale: the schedule editor should support manual/ad hoc authoring and AI-imported drafts without re-coupling official match-sheet state to mutable library teams.
- Date/Author: 2026-03-30 / Codex

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
- Follow-up implementation decoupled iPhone scheduled-match editing from `TeamRecord` selection, removed source-team reseeding/edit UI, and kept existing `sourceTeamId` / `sourceTeamName` plus schedule `homeTeamId` / `awayTeamId` as preserved stored data instead of editor-driven state. A later PM tweak restored Teams library/catalog name autofill buttons that update only the visible home/away strings while using the app’s existing Teams library/catalog flow.
- Updated watch substitution selection to prefer ready frozen match sheets, fall back to numeric/manual entry when explicit sheets are incomplete, and retain linked-library fallback only for legacy no-sheet schedules.
- Applied Supabase migration `0022_schedule_match_sheets` to the live project and confirmed `public.scheduled_matches` now exposes `home_match_sheet` and `away_match_sheet`.
- Follow-up review fixes keep orphaned schedule sheets from losing preserved source-team provenance and make editor-authored player/staff/member order explicit and stable on save.
- Added targeted iOS regression coverage for preserved source-team metadata, match-sheet persistence round-trips, aggregate hydration, and authored-order normalization.
- Shared-core normalization now reindexes starters, substitutes, staff, and `otherMembers` contiguously so persisted order remains explicit after save/load across storage and sync paths.
- Validation evidence now includes targeted shared-core passes, historical targeted iPhone regression-slice and simulator-build passes on `iPhone 15 Pro Max (iOS 17.0.1)`, and decoupling-specific save-path coverage; the latest 2026-03-31 autofill-only reruns remained blocked in simulator/XCTest harness failures before product assertions.
- Historical blocker only: 2026-03-30 iPhone UI reruns stopped at simulator/XCTest failures before the updated import-to-save path completed, but that gap was later closed by the 2026-03-31 optional-sheet hardening pass, which reran `MatchSheetImportUITests` to a clean passing xcresult.
- Deferred only: direct watch `SubstitutionFlow` UI branch coverage for `.frozenSheet` / `.manualOnly` / `.legacyLibrary`, because shared-core precedence coverage already exists and the watch target does not currently expose a lightweight view-inspection harness.
