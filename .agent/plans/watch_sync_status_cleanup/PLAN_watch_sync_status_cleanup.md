# Purpose / Big Picture
Ensure match status stays in sync across watchOS and iOS so referees only see actionable fixtures. The watch “Saved Matches” picker should surface upcoming fixtures only, completed matches should fall out of the iOS “Upcoming” list the moment they finish, and the active match timer must keep the selected team names visible from kickoff through full time.

# Surprises & Discoveries
- **CRITICAL**: Status enum decoder silently fails for in-progress matches. The Supabase database returns `"in_progress"` (snake_case), but `ScheduledMatch.Status(rawValue:)` expects `"inProgress"` (camelCase), causing all in-progress schedules to fallback to `.scheduled`.
  - Evidence: Database query returns `status: "scheduled"` for all rows; enum has no decoder for snake_case; SwiftDataScheduleStore.swift:171 uses `Status(rawValue:)`.
  - Impact: Without fixing this first, all filtering logic in subsequent tasks will incorrectly treat in-progress matches as scheduled.
- Observation: `MatchViewModel.updateLibrary` converts every schedule into a selectable match without inspecting `statusRaw`, so completed/canceled fixtures appear in `savedMatches`.
  - Evidence: RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift:137-174.
- Observation: Locally created matches are appended to `localSavedMatches` during `createMatch()` but never pruned when the match is finalized, leaving stale entries in the picker.
  - Evidence: RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift:122-152, 836-865.
- Observation: `MatchesTabView.handleScheduleUpdate` only buckets matches by kickoff date; it ignores `ScheduledMatch.status`, so completed items continue to render under "Today"/"Upcoming".
  - Evidence: RefZoneiOS/Features/Matches/Views/MatchesTabView.swift:286-295.
- Observation: `IOSConnectivitySyncClient.persist` saves completed matches to history but never updates the related schedule record, leaving its status at `.scheduled`.
  - Evidence: RefZoneiOS/Core/Platform/Connectivity/IOSConnectivitySyncClient.swift:262-283.
- Observation: `TimerView.scoreDisplay` passes `model.homeTeam` / `model.awayTeam` (the fallback defaults) to `ScoreDisplayView`, so once kickoff starts the UI reverts to "Arsenal vs Blue Eagles".
  - Evidence: RefZoneWatchOS/Features/Timer/Views/TimerView.swift:149-168.
- Observation: `LiveActivityStatePublisher.deriveState` also uses `match.homeTeam` / `match.awayTeam` for live activity abbreviations, causing iOS Live Activities to show fallback names after kickoff.
  - Evidence: RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityStatePublisher.swift:60-61.

# Decision Log
- Decision: **[PRE-WORK]** Add custom decoder `ScheduledMatch.Status.init(fromDatabase:)` to explicitly map snake_case database values to Swift enum cases before implementing any filtering logic.
  - Rationale: The database returns `"in_progress"` but Swift expects `"inProgress"`. Current code using `Status(rawValue:)` silently fails and defaults to `.scheduled`, breaking all downstream filtering. Must fix this foundation issue first.
  - Date/Author: 2025-10-23 / Technical Review
- Decision: Filter library schedules to upcoming/in-progress statuses before merging into `savedMatches`, and drop completed local matches during `finalizeMatch()`.
  - Rationale: Prevents referees from relaunching finished fixtures and keeps the picker aligned with pre-match workflows.
  - Date/Author: 2025-10-23 / Codex
- Decision: Inject `ScheduleStoring` into `IOSConnectivitySyncClient` so the iOS side can mark schedules as `.completed` when a finished match arrives and refresh Combine publishers, avoiding destructive deletes that would violate database constraints.
  - Rationale: Keeps the iPhone “Upcoming” section truthful and propagates status changes back to the watch aggregate snapshot.
  - Date/Author: 2025-10-23 / Codex
- Decision: Update the matches UI filtering logic to exclude `.completed`/`.canceled` schedules from “Today” and “Upcoming”, while retaining `.inProgress`.
  - Rationale: Completed fixtures should shift immediately to history without requiring a manual refresh.
  - Date/Author: 2025-10-23 / Codex
- Decision: Audit timer-facing views so they always read `homeTeamDisplayName` / `awayTeamDisplayName` (or `currentMatch`), preventing fallback defaults from resurfacing mid-match.
  - Rationale: Ensures on-field officials see the correct teams after kickoff, reducing confusion during live play.
  - Date/Author: 2025-10-23 / Codex
- Decision: Add focused unit coverage for saved-match filtering, schedule status propagation, and timer label rendering to lock in the regressions discovered by QA.
  - Rationale: Provides fast feedback if future refactors reintroduce stale schedule entries or incorrect team names.
  - Date/Author: 2025-10-23 / Codex

# Outcomes & Retrospective
- Completed TASK_00–TASK_04: database status decoding now aligns with Supabase payloads, watch saved matches stay limited to actionable fixtures, iOS propagates completion status into schedules/Upcoming lists, and timer plus live activity surfaces stick with the active match’s team names end-to-end.
- All new regression suites were added (decoder, watch library filtering, connectivity schedule updates, timer/live activity labels, Matches tab filtering). Simulator-based test runs were attempted after each phase but remain blocked in this environment by missing `GoogleSignIn` (iOS) and `RefZoneWatchOS` (watch) modules; manual or CI verification is recommended.

# Context and Orientation
- `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift` owns watch match state, saved match aggregation, and lifecycle hooks (`createMatch`, `finalizeMatch`).
- `RefWatchCore/Sources/RefWatchCore/Domain/MatchLibraryModels.swift` supplies schedule metadata (`statusRaw`) fed into the watch library snapshot.
- `RefZoneWatchOS/Core/Components/MatchStart/SavedMatchesListView.swift` and `StartMatchOptionsView.swift` surface the combined saved matches list produced by the view model.
- `RefZoneiOS/Core/Platform/Connectivity/IOSConnectivitySyncClient.swift` receives completed match snapshots from the watch and currently only persists them to the history store.
- `RefZoneiOS/Core/Services/ScheduleService.swift` / `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataScheduleStore.swift` implement `ScheduleStoring`, the abstraction we will use to mark schedules as completed.
- `RefZoneiOS/Features/Matches/Views/MatchesTabView.swift` renders “Today”, “Upcoming”, and “Past” sections using the schedule store snapshot and requires refined filtering.
- `RefZoneWatchOS/Features/Timer/Views/TimerView.swift` renders `ScoreDisplayView`, which must consume the display-name helpers tied to `currentMatch`.
- `RefZoneWatchOS/Core/Services/LiveActivity/LiveActivityStatePublisher.swift` derives live activity state for iOS widgets and must use `currentMatch` team names instead of fallback properties.

# Pre-Work (Critical)

**⚠️ BLOCKING**: The following task must be completed BEFORE any other implementation work can begin.

0. **Fix status enum decoder** (TASK_00)
   - **Problem**: Database returns `"in_progress"` (snake_case), but `ScheduledMatch.Status` enum uses `"inProgress"` as its rawValue (camelCase). Current code using `Status(rawValue: "in_progress")` returns `nil`, falling back to `.scheduled`.
   - **Impact**: ALL filtering logic in TASK_01/TASK_02 will incorrectly treat in-progress matches as scheduled, perpetuating the bug instead of fixing it.
   - **Solution**: Add custom decoder `Status.init(fromDatabase:)` that explicitly maps snake_case database values to Swift enum cases.
   - **Files affected**:
     - `RefZoneiOS/Core/Models/ScheduledMatch.swift` (add decoder extension)
     - `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataScheduleStore.swift:171` (use new decoder)
     - `RefZoneiOS/Core/Persistence/SwiftData/ScheduledMatchRecord.swift:74` (use new decoder)
   - **Testing**: Unit tests must verify all four database statuses (`scheduled`, `in_progress`, `completed`, `canceled`) decode correctly.
   - **Estimated effort**: 1.5 hours

# Plan of Work
1. **Watch saved matches hygiene**
   - Introduce a helper that maps `MatchLibrarySchedule.statusRaw` to `ScheduledMatch.Status`, filter for `.scheduled`/`.inProgress`, and default all unknown/missing statuses to `.scheduled` while surfacing telemetry so we can flag legacy payloads.
   - When `finalizeMatch()` fires, remove any matching entry from `localSavedMatches`, then recompute `savedMatches` so completed local fixtures disappear immediately.
   - Add tests in the watch target to confirm completed schedules/local matches are excluded and that filtering tolerates missing status metadata.
2. **iOS schedule status propagation**
   - Extend `IOSConnectivitySyncClient` to accept a `ScheduleStoring` dependency; ensure `persist(_:)` executes on the main actor (via `@MainActor` or `MainActor.run`) when loading and marking schedules `.completed`, and emit analytics/queued actions when the schedule record is missing so background completions eventually reconcile.
   - Update `ConnectivitySyncController` (and callers) to pass the schedule store when constructing the client.
   - Refine `MatchesTabView.handleScheduleUpdate` to drop `.completed`/`.canceled` items from “Today” and “Upcoming” while keeping `.inProgress`. Consider extracting the filter into a testable helper.
   - Cover the pipeline with unit tests that simulate a completed match arriving (including a missing-schedule scenario) and verify the upcoming list shrinks accordingly.
3. **Timer team label integrity**
   - Update `TimerView.scoreDisplay` (and any related overlays) to consume `homeTeamDisplayName`/`awayTeamDisplayName` or the `currentMatch` properties directly.
   - Verify no other timer-era views—including live activity and complication publishers—still rely on the fallback `homeTeam` / `awayTeam` properties after kickoff.
   - Add a UI-driven unit test that sets `currentMatch` and asserts the timer uses the correct names after invoking `startMatch()`.

# Concrete Steps
- **[PRE-WORK]** (TASK_00_watch_sync_status_cleanup.md) Fix status enum decoder to handle database snake_case format. **BLOCKS ALL OTHER TASKS.**
- (TASK_01_watch_sync_status_cleanup.md) Restrict watch saved matches to upcoming fixtures and prune local entries on completion.
- (TASK_02_watch_sync_status_cleanup.md) Propagate completion status to the iOS schedule store and tighten Upcoming filtering.
- (TASK_03_watch_sync_status_cleanup.md) Keep timer and live activity displays bound to the active match's team names.
- (TASK_04_watch_sync_status_cleanup.md) Add regression tests covering decoder fix, saved-match filtering, schedule status updates, timer labels, and live activity names.

# Progress
[x] **[PRE-WORK]** (TASK_00_watch_sync_status_cleanup.md) 2025-10-21 17:22 — Added `Status.fromDatabase`, updated SwiftData stores, created decoder tests; `xcodebuild` attempted (fails to build due to missing GoogleSignIn module in current environment).

[x] (TASK_01_watch_sync_status_cleanup.md) 2025-10-21 17:35 — Filtered library schedules to active statuses, pruned local saved matches on finalize, added watch filtering tests; watch test suite invocation fails to locate `RefZoneWatchOS` module in current environment.

[x] (TASK_02_watch_sync_status_cleanup.md) 2025-10-21 17:44 — Injected schedule store into connectivity client, marked schedules completed, tightened Matches tab filtering, added iOS regression tests; RefZoneiOS test run still fails to build (`GoogleSignIn` module missing).

[x] (TASK_03_watch_sync_status_cleanup.md) 2025-10-21 17:53 — Updated timer and live activity displays to use dynamic team names, added watch regression tests; watch test run still fails because `RefZoneWatchOS` module is unavailable in this environment.

[x] (TASK_04_watch_sync_status_cleanup.md) 2025-10-21 17:54 — Added MatchesTabView filtering regression tests and ensured all new suites exist; full watch/iOS test runs attempted but still blocked by missing `GoogleSignIn` / `RefZoneWatchOS` modules.

# Testing Approach
- Watch target: Extend `MatchViewModel` unit tests to cover schedule-status filtering (including nil/unknown statuses) and local saved match cleanup, exercising both remote and watch-authored matches.
- iOS target: Add tests for the updated `IOSConnectivitySyncClient` (mocking `ScheduleStoring`) and for the extracted schedule-filter helper used by `MatchesTabView`, including scenarios where the schedule is absent/offline.
- UI validation: Run the `RefZone Watch App` and `RefZoneiOS` schemes after implementation; manually verify that completing a match removes it from watch saved matches and iOS Upcoming, and that timer names remain correct.

# Constraints & Considerations
- `ScheduleStoring` is `@MainActor`; updates inside `IOSConnectivitySyncClient.persist` must remain on the main actor to avoid SwiftData threading violations.
- Filtering logic must tolerate legacy snapshots without `statusRaw` by falling back to `.scheduled` and emitting telemetry rather than erroring.
- Ensure watch/iOS sync payloads stay backward compatible—avoid renaming Codable properties in shared models.
- Avoid deleting schedule rows; Supabase enforces `matches_scheduled_match_id_fkey`, so we must update status fields instead of removing records.
- Coordinate with the Supabase/back-end owners to confirm the authoritative `match_status` enum values (e.g., postponed) so filtering logic remains future-proof.
- Timer label fixes should not regress existing complications or live activity publishers that might still read the fallback team properties.
- Local simulator builds cannot currently link GoogleSignIn (iOS) or resolve the `RefZoneWatchOS` module for watch tests; rely on CI or physical devices to validate test execution until the toolchain is corrected.
