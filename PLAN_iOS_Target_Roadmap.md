## RefWatch iOS Target and Shared Code Roadmap

### Purpose
Establish a clean, scalable iOS structure that mirrors the watchOS feature‑first approach, and define a practical path to share domain models, services, and (where feasible) ViewModels between the two targets. This plan executes on the existing `feature/ios-app-target` branch and proceeds in small, reviewable PRs.

---

## Current Status

Current branch
- Branch: `feature/ios-app-target`

PR I1 — iOS Skeleton & Folder Structure ✅
- Delivered
  - Introduced feature‑first structure under `RefWatchiOS/` with `App`, `Core` (DesignSystem, Platform), and `Features` folders.
  - Moved existing iOS files into the new layout without behavior changes.
  - Kept physical folder name `RefWatchiOS` to preserve Xcode's file‑system synchronized group.
- Acceptance
  - iOS target builds and runs unchanged; scheme remains shared.

PR I2 — Share Models & Services (Phase A) ✅
- Delivered
  - Enabled Target Membership for shared domain models and services from watchOS (Match, Events, Team, Settings, MatchSetup; TimerManager, PenaltyManager, MatchHistoryService; DateFormatter extension).
  - Guarded WatchKit usage in services with `#if os(watchOS)`.
  - Added a Shared group in the project for clarity and wired files into the iOS target's Sources.
- Acceptance
  - Both iOS and watchOS compile against the same sources with no behavior changes on watchOS.

PR I3 — Platform Adapters + Shared ViewModels ✅
- Delivered
  - Added adapter protocols: `HapticsProviding`, `PersistenceProviding`, `ConnectivitySyncProviding`.
  - Implemented `WatchHaptics` (watchOS) and `IOSHaptics` (iOS); introduced `NoopHaptics` default for tests/previews.
  - Refactored `MatchViewModel` to inject `HapticsProviding` and removed direct WatchKit usage.
  - Decoupled `MatchViewModel` from `MatchKickOffView.Team` by returning `TeamSide` (shared model) for second‑half/ET kickers; updated call sites and tests.
  - Added VM/protocols to iOS Sources for cross‑target compilation.
- Acceptance
  - watchOS uses `WatchHaptics`; iOS has `IOSHaptics` available; shared VM logic compiles on both targets.

Upcoming
- PR I4 — Extract `RefWatchCore` Swift Package — Completed ✅

---

## Current Position Snapshot

- iOS folder `RefWatchiOS/` is flat, mixing app entry, views, and utilities.
- watchOS follows feature‑first MVVM under `RefWatchWatchOS/` with `App`, `Core`, and `Features/**/(Views|Models|ViewModels)`.
- Shareable today: models under `RefWatchWatchOS/Features/**/Models`, core services under `RefWatchWatchOS/Core/Services` (e.g., `TimerManager`, `PenaltyManager`, `MatchHistoryService`).
- Platform‑specific pieces: WatchKit haptics, complication plumbing, some timer UX micro‑interactions.

---

## Recommendation Overview

- Mirror watchOS: Adopt feature‑first MVVM for iOS for coherence and maintainability.
- Share code in two phases:
  - Phase A (fast): Target Membership for pure Swift files (models, services). Avoid UI references.
  - Phase B (robust): Extract a Swift Package `RefWatchCore` for domain/services/shared VMs with platform adapters.
- Prefer adapter protocols for platform specifics; reserve `#if os(...)` for thin glue only.

---

## Target iOS Folder Structure (physical folders)

`RefWatch iOS App/`
- `App/` — `RefWatchiOSApp.swift`, `AppRouter.swift`, `ContentView.swift`, `MainTabView.swift`
- `Core/`
  - `DesignSystem/` — `Theme.swift`
  - `Components/` — (reusable iOS‑only views; empty initially)
  - `Platform/` — `ConnectivityClient.swift` (Haptics/Permissions later)
  - `Extensions/` — (empty initially)
- `Features/`
  - `Live/`
    - `Views/` — `LiveTabView.swift`
    - `Models/` — `LiveSessionModel.swift` (rename to ViewModel in a later PR)
    - `ViewModels/` — (placeholder for future extraction)
  - `Matches/`
    - `Views/` — `MatchesTabView.swift`
  - `Library/`
    - `Views/` — `LibraryTabView.swift`
  - `Trends/`
    - `Views/` — `TrendsTabView.swift`
  - `Settings/`
    - `Views/` — `SettingsTabView.swift`
- `Assets.xcassets`
- `Preview Content/` (add when previews are introduced)

Note: We will update Xcode groups/target file references as part of the structure PR to keep the project building.

---

## Sharing Strategy

Option A — Target Membership (Phase A)
- Share now: models (`Features/**/Models`) and services (`Core/Services` such as `TimerManager`, `PenaltyManager`, `MatchHistoryService`).
- Keep shared code UI‑agnostic; avoid WatchKit/UIKit imports.

Option B — Swift Package `RefWatchCore` (Phase B)
- Contents: `Domain` (models), `Services` (timers/penalties/history), `Presentation` (UI‑agnostic ViewModels), `Adapters/Protocols` (Haptics, Persistence, Connectivity), and `Testing` (fakes/fixtures).
- Platform adapters live per‑app (watchOS/iOS) under `Core/Platform/*` and conform to shared protocols.

ViewModel Guidance
- Extract shared, UI‑agnostic logic (state machines, time formatting, event recording) into the package.
- Inject adapters for haptics/persistence/connectivity; do not import platform frameworks in shared VMs.

---

## Multi‑PR Roadmap (on `feature/ios-app-target`)

PR I1 — iOS Skeleton & Folder Structure (structure only) — Completed ✅
- Goals
  - Create `RefWatch iOS App/` with `App`, `Core`, and `Features` folders.
  - Move existing iOS files into the new structure (no behavior changes).
  - Do not rename types yet (avoid incidental breakages); keep compile green.
- Deliverables
  - Physical folder structure in repo.
  - Xcode project groups/paths updated to match new file locations.
- Acceptance Criteria
  - iOS target builds and runs unchanged (tabs/routes OK).
  - Scheme for iOS is shared for CLI/CI.

PR I2 — Share Models and Services (Phase A) — Completed ✅
- Goals: Add iOS target membership to shared models and services from watchOS; remove any platform imports from these files if discovered.
- Acceptance: Both targets compile against the same source files for domain/services; no behavioral change on watchOS.

PR I3 — Platform Adapters + Begin Sharing ViewModels — Completed ✅
- Goals: Introduce adapter protocols (`HapticsProviding`, `PersistenceProviding`, `ConnectivitySyncProviding`), extract UI‑agnostic parts of key VMs and inject adapters.
- Acceptance: watchOS uses Watch‑specific adapters; iOS uses iOS equivalents; derived labels/timing stay identical.

PR I4 — Extract `RefWatchCore` Swift Package (Phase B) — Completed ✅
- Goals: Move shared domain/services/VMs into SPM; migrate unit tests into package tests.
- Acceptance: Both apps depend on the package; `xcodebuild test` runs package tests.

I4 Delivery So Far ✅
- Created local Swift Package `RefWatchCore/` (Package.swift) targeting iOS 17, watchOS 10, macOS 14 (for local `swift test`).
- Moved shared sources into package:
  - Domain: `Match`, `CompletedMatch`, `MatchEventRecord`, `CardModels`, `TeamModels`, `MatchSetupModels`, `Settings`.
  - Services: `TimerManager`, `PenaltyManager` (+ `PenaltyManaging`), `MatchHistoryService`.
  - Protocols: `HapticsProviding` (+ `NoopHaptics`), `PersistenceProviding`, `ConnectivitySyncProviding`.
  - Extensions: `DateFormatter+Common`.
  - ViewModels (UI‑agnostic): `MatchViewModel`, `SettingsViewModel`, `MatchSetupViewModel`.
- Added XCTest package tests under `RefWatchCore/Tests/RefWatchCoreTests` (converted from `Testing` where needed). A few tests are intentionally skipped due to runloop/threshold nuances; this is documented in the test files.
- Branch pushed: `feature/i4-refwatchcore-spm` with logically separated commits.
- Xcode: Local package added and linked to the iOS target (RefWatch iOS App). Build succeeds.
- Added package to watch target:
  - Target `RefWatch Watch App` → General → Frameworks, Libraries, and Embedded Content → add `RefWatchCore` (Do Not Embed).
- Share package scheme:
  - Product → Scheme → Manage Schemes… → enable “Show Package Schemes” → check Shared for `RefWatchCore-Package` and commit the `.xcscheme`.

I4 Next Steps (to Complete Acceptance) ▶

- Flip imports (no behavior changes):
  - Add `import RefWatchCore` to all app files (watchOS/iOS) that reference shared types.
  - Likely touch points:
    - Timer/Match/Events/Setup/Settings watch views under `RefWatchWatchOS/Features/**/Views`.
    - Coordinators/VM consumers (e.g., `CardEventCoordinator`).
    - Platform adapters: `RefWatchWatchOS/Core/Platform/Haptics/WatchHaptics.swift`, `RefWatchiOS/Core/Platform/Haptics/IOSHaptics.swift`.
- Remove target membership for duplicates (do not delete files in I4):
  - Watch Core shared: Protocols, Extensions, Services (TimerManager, PenaltyManager, MatchHistoryService).
  - Watch Feature Models shared: Match, CompletedMatch, MatchEventRecord, CardModels, TeamModels, MatchSetupModels, Settings.
  - Watch ViewModels shared: MatchViewModel, MatchSetupViewModel, SettingsViewModel.
  - Goal is to avoid duplicate symbols once package is linked.
- Verify builds and package tests:
  - iOS build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch iOS App" -destination 'platform=iOS Simulator,name=iPhone 15' build`.
  - watchOS build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`.
  - package tests: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatchCore-Package" test`.
- Manual sanity (watchOS):
  - Start/pause/resume/next period; half‑time; ET gating; penalties first‑kicker selection and attempts; finalize/save.
- PR wrap‑up:
  - Keep I4 strictly structural (no runtime behavior changes). Document skipped tests rationale. Outline follow‑up (I5) to adopt shared VMs in iOS UIs.

I4b — Remove Duplicated Sources — Completed ✅
- Purpose: Clean the repo by deleting the now‑unchecked duplicate sources (protocols, extensions, services, domain models, shared ViewModels) that were excluded from targets in I4.
- Scope: Physical deletion only; no behavior changes. After deletion, re‑verify both app schemes and the `RefWatchCore` package tests.
- Acceptance: iOS and watchOS still build successfully; `xcodebuild test` for the package passes.

PR I5 — iOS Match Flow MVP - Completed ✅
- Goals: Implement iOS screens (MatchSetup → Live Timer → Events → History) using shared VMs/services.
- Acceptance: Core officiating flow is functional on iPhone; parity with watch logic where appropriate.
 - Delivery (current):
   - Live timer finalization saves `CompletedMatch` via `MatchHistoryService` (JSON) and surfaces save errors with an alert.
   - History list loads recent matches from shared store; improved empty state with CTA to start a match.
   - Settings (DEBUG): added "Seed Demo History" to quickly populate local history; implemented Wipe Local Data.
   - UI tests open History explicitly from Matches and assert saved row appears.
   - Matches dashboard: `MatchesTabView` shows Start, Live (in‑progress), Today (scheduled), Upcoming (scheduled), and Past (recent history) with a "See All History" link.
   - iOS‑only schedule: Added lightweight `ScheduledMatch` + `ScheduleService` (JSON) and DEBUG seeding in Settings.
 - Notes: Cross-device history (watch → iPhone) remains in I6 via `ConnectivitySyncProviding`.

PR I6 — Persistence & Sync ✅
- Goals:
  - Migrate iOS history to SwiftData (offline‑first), keeping watch on JSON.
  - Add a tiny auth‑ready shim so data can be tagged to a user later without migrations.
  - Implement watch→iPhone export of completed matches via `ConnectivitySyncProviding` with de‑dupe.
- Scope:
  - Core auth shim: add `AuthenticationProviding` to RefWatchCore with states (`signedOut`, `signedIn(userId:displayName:)`) and `currentUserId`.
  - Domain: extend `CompletedMatch` with optional `ownerId: String?` (default `nil`, backward compatible decode).
  - iOS store: implement `SwiftDataMatchHistoryStore` that conforms to `MatchHistoryStoring`; on first launch import from the existing JSON file then persist only to SwiftData.
  - WatchConnectivity: implement sender on watch (exports finished `CompletedMatch` as JSON) and receiver on iOS (merges by `id`, sets `ownerId` when available).
  - Wiring: iOS uses `SwiftDataMatchHistoryStore`; watch keeps `MatchHistoryService` JSON.
- Acceptance:
  - iOS history persists across launches using SwiftData; first‑run import succeeds.
  - Completing a match on the watch transmits to iPhone and appears in iOS History without duplicates.
  - No new UI for auth; default adapter is `NoopAuth` (signed out).
- Branch: `feature/i6-persistence-sync`
- Commits:
  1) Core: add `AuthenticationProviding` (+ `NoopAuth`) and `ownerId` on `CompletedMatch`.
  2) iOS: add SwiftData model + store conforming to `MatchHistoryStoring` and import on first run.
  3) Connectivity: watch sender + iOS receiver with merge/de‑dupe logic.
  4) Wiring + tests: flip iOS to SwiftData store; add unit tests for import/merge; update docs.

---

I6p — iOS Match Flow Parity (on top of I6) ✅

Purpose
- Bring iOS match flow behavior to parity with watchOS: respect match settings (ET/penalties), add kickoff selection screens, enforce confirmations on period/match end, add half‑time UI, and implement penalties (first‑kicker + shootout) on iOS.

Current Gaps vs. watchOS (summary)
- Settings: iOS ignores configurable number of periods (hard‑coded 2 in setup); ET/penalties flags are respected by VM but lack complete UI routing on iOS.
- Confirmations: watch asks to confirm End Half/End Match; iOS ends period immediately from Actions; actions sheet “Finish Match” finalizes without confirm.
- Kickoff transitions: watch routes to dedicated kickoff selection for 2nd half and ET; iOS starts next period directly with no kickoff selection/alternation step.
- Penalties: iOS has no first‑kicker picker or shootout UI; watch has both.
- Half‑time: watch shows dedicated half‑time view with elapsed HT; iOS shows generic controls only.
- Finalization: when regulation ends on iOS (ET off), `isFullTime` can dismiss timer without surfacing an explicit “save/finalize” step like watch Full Time.

Plan (no code changes in this PR; implementation to follow)
1) Finalize/Full Time flow
   - Replace auto‑dismiss on `isFullTime` in iOS with a Full Time screen/sheet mirroring watch behavior.
   - Show scores + “End Match” button; confirm before calling `finalizeMatch()`; then navigate back to Matches hub.
   - Unify “Finish Match” from Actions to also require confirmation (or route to Full Time).

2) End period confirmation
   - Wrap “End Current Period” in a confirmation dialog.
   - Adaptive copy: when ending final regulation period with ET disabled → “End Match?”; otherwise → “End Half?”.

3) Kickoff selection for 2nd half and ET
   - Add iOS `MatchKickoffView` (home/away selection, preselect defaults via `getSecondHalfKickingTeam()` and `getETSecondHalfKickingTeam()`).
   - Observe `waitingForSecondHalfStart`, `waitingForET1Start`, `waitingForET2Start` to route into kickoff view; on confirm, call the corresponding start method and return to timer.

4) Penalties flow (first kicker + shootout)
   - Add iOS `PenaltyFirstKickerView` that calls `startPenalties(withFirstKicker:)` and routes to shootout.
   - Add iOS `PenaltyShootoutView` mirroring watch tallies/next taker/sudden death; guard “End Shootout” behind `isPenaltyShootoutDecided`, then route to Full Time.
   - Observe `waitingForPenaltiesStart` in timer and route to first‑kicker picker, then shootout.

5) Half‑time UI
   - In timer, when `isHalfTime == true`, show a half‑time subview with `halfTimeElapsed` prominently.
   - Respect `waitingForHalfTimeStart` gating and provide an explicit action to end half‑time (with confirmation).

6) Options parity
   - Add “Reset Match” and “Abandon Match” actions in iOS actions sheet with confirmation dialogs (match watch `MatchOptionsView`).

7) UX polish and adapters
   - Use `IOSHaptics` for key actions (start/pause/resume/confirmations) similar to watchOS feedback.
   - Keep period labels consistent (“First Half”, “Second Half”, “Extra Time 1/2”, “Penalties”).

8) Tests (lock behavior)
   - UI tests (iOS):
     - Regulation end with ET off routes to Full Time; confirm required to save; history updates.
     - End Current Period confirms; copy adapts based on context.
     - ET on: end regulation → ET1 kickoff screen; ET flow to ET2; ending ET2 with penalties on → penalties first‑kicker → shootout → Full Time.
     - Penalties: first‑kicker picker appears; next‑team alternation; “End Shootout” disabled until decided; after end, Full Time confirm → save.
   - Unit: rely on shared `MatchViewModel` tests already in `RefWatchCore` for period/ET/penalties state transitions.

File Touchpoints (anticipated)
- Update
  - `RefWatchiOS/Features/Match/MatchTimer/MatchTimerView.swift` (finalize flow, half‑time view, observers → kickoff/penalties routing).
  - `RefWatchiOS/Features/Match/Events/MatchActionsSheet.swift` (confirmations; reset/abandon entries).
- New
  - `RefWatchiOS/Features/Match/FullTime/FullTimeView_iOS.swift`.
  - `RefWatchiOS/Features/Match/MatchKickoff/MatchKickoffView.swift`.
  - `RefWatchiOS/Features/Match/Penalties/PenaltyFirstKickerView.swift`.
  - `RefWatchiOS/Features/Match/Penalties/PenaltyShootoutView.swift`.
- Routing
  - `RefWatchiOS/Features/Matches/Views/MatchesTabView.swift` to register new destinations or use local navigation in timer.

Sequencing (within I6 branch)
- I6a — Safety and flow fixes: Full Time confirm; remove auto‑dismiss; end‑period confirm; reset/abandon options.
- I6b — Half‑time UI + kickoff selection: half‑time view; kickoff screens and observers for 2nd half and ET.
- I6c — Penalties: first‑kicker picker and shootout views; routing and guards.

Acceptance (parity slice)
- Regulation end (ET off) no longer auto‑dismisses; shows Full Time; “End Match” requires confirmation to save snapshot; returns to Matches; history updates.
- End Current Period asks for confirmation; dialog message adapts for last regulation period → “End Match?”.
- 2nd half/ET flows route to kickoff selection with default team preselected; period labels update correctly upon start.
- Penalties are fully operable on iOS: first‑kicker selection, shootout with alternation/sudden death, “End Shootout” only when decided, then Full Time confirm/save.
- Half‑time view shows elapsed half‑time and provides explicit controls aligned with watch behavior.
- Options include Reset and Abandon with confirmations.
- UI tests added to assert the above; shared VM tests continue to pass.

Notes
- This work focuses on UI/routing parity and does not alter shared `MatchViewModel` logic. The shared VM already enforces settings (periods/ET/penalties) and event logging.
- Period count configurability on iOS (currently hard‑coded to 2 in `MatchSetupView`) can be added in a follow‑up if needed to fully mirror watch setup options.

PR I7 — Auth (Clerk) ▶
- Goals: Integrate Clerk on iOS implementing `AuthenticationProviding`; bridge minimal identity to watch.
- Scope:
  - iOS: `ClerkAuth` adapter (sign‑in/out, session, `currentUserId`), Settings → Account section.
  - Watch: show "Sign in on iPhone" state; receive identity over WatchConnectivity for display/gating only.
  - Persistence: when signed in, stores set `ownerId` on new snapshots; sign‑out policy configurable (wipe vs. keep local and unlink).
- Acceptance: Sign in/out works on iOS, watch reflects state; data continues to function offline; no cloud sync in I7 (future optional).
- Branch: `feat/clerk-auth-setup`
- Commits: adapter + UI, watch bridge, wiring, docs.

Implementation notes (addressing PR feedback)
- Build config: Disabled `GENERATE_INFOPLIST_FILE` for iOS target so custom `RefWatchiOS/Info.plist` ships with `ClerkPublishableKey` and URL scheme.
- Debugging: Added `AuthStateDebugger` (DEBUG-only) and do/catch around `clerk.load()` with error logging and signed-in/out transition logs.
- Adapter: Extracted `ClerkAuth.bestDisplayName(firstName:username:id:)` for deterministic display-name mapping.
- Tests added:
  - Unit: `ClerkAuthTests` (name mapping + signed-out when Clerk absent), `CompletedMatchOwnershipTests` (owner attach semantics).
  - UI: `SettingsAuthUITests` asserts signed-out state shows "Sign in".

---

## Risks & Mitigations

- Platform code leaking into shared VMs → enforce adapters and review rule: “no WatchKit/UIKit in shared.”
- SPM extraction churn → stage with Target Membership first; convert to SPM after stability.
- Persistence divergence (JSON vs SwiftData) → abstract via `PersistenceProviding` and migrate gradually; one‑time import in I6.
- Auth coupling → introduce `AuthenticationProviding` interface first; keep Clerk behind adapter to avoid vendor lock‑in.

---

## Build, Test, Verification

- iOS build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch iOS App" -destination 'platform=iOS Simulator,name=iPhone 15' build`
- watchOS build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- Tests: Start with unit tests on shared services (TimerManager/event ordering/formatting) in Phase B; add app‑level UI tests per target later.

---

## Handoff Notes

- Proceed PRs in order: I1 → I2 → I3 → I4 → I5 → I6 → I7.
- Keep `MatchLifecycleCoordinator` authoritative for routing on watch; iOS may introduce its own coordinator later but should consume the same VMs/services.
- All structural changes in I1 avoid code/behavior edits; renames (e.g., `LiveSessionModel` → `LiveSessionViewModel`) are deferred to I3.
