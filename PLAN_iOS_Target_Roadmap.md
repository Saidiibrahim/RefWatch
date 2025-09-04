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
- PR I4 — Extract `RefWatchCore` Swift Package — In Progress ▶

---

## Current Position Snapshot

- iOS folder `RefWatchiOS/` is flat, mixing app entry, views, and utilities.
- watchOS follows feature‑first MVVM under `RefWatch Watch App/` with `App`, `Core`, and `Features/**/(Views|Models|ViewModels)`.
- Shareable today: models under `RefWatch Watch App/Features/**/Models`, core services under `RefWatch Watch App/Core/Services` (e.g., `TimerManager`, `PenaltyManager`, `MatchHistoryService`).
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

PR I4 — Extract `RefWatchCore` Swift Package (Phase B) — In Progress ▶
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
    - Timer/Match/Events/Setup/Settings watch views under `RefWatch Watch App/Features/**/Views`.
    - Coordinators/VM consumers (e.g., `CardEventCoordinator`).
    - Platform adapters: `RefWatch Watch App/Core/Platform/Haptics/WatchHaptics.swift`, `RefWatchiOS/Core/Platform/Haptics/IOSHaptics.swift`.
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

I4b — Remove Duplicated Sources ▶
- Purpose: Clean the repo by deleting the now‑unchecked duplicate sources (protocols, extensions, services, domain models, shared ViewModels) that were excluded from targets in I4.
- Scope: Physical deletion only; no behavior changes. After deletion, re‑verify both app schemes and the `RefWatchCore` package tests.
- Acceptance: iOS and watchOS still build successfully; `xcodebuild test` for the package passes.

PR I5 — iOS Match Flow MVP
- Goals: Implement iOS screens (MatchSetup → Live Timer → Events → History) using shared VMs/services.
- Acceptance: Core officiating flow is functional on iPhone; parity with watch logic where appropriate.

PR I6 — Persistence & Sync (Optional)
- Goals: SwiftData on iOS behind `PersistenceProviding`; WatchConnectivity export of completed matches.
- Acceptance: iOS history persists; watch→phone export works.

---

## Risks & Mitigations

- Platform code leaking into shared VMs → enforce adapters and review rule: “no WatchKit/UIKit in shared.”
- SPM extraction churn → stage with Target Membership first; convert to SPM after stability.
- Persistence divergence (JSON vs SwiftData) → abstract via `PersistenceProviding` and migrate gradually.

---

## Build, Test, Verification

- iOS build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch iOS App" -destination 'platform=iOS Simulator,name=iPhone 15' build`
- watchOS build: `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`
- Tests: Start with unit tests on shared services (TimerManager/event ordering/formatting) in Phase B; add app‑level UI tests per target later.

---

## Handoff Notes

- Proceed PRs in order: I1 → I2 → I3 → I4 → I5 → I6.
- Keep `MatchLifecycleCoordinator` authoritative for routing on watch; iOS may introduce its own coordinator later but should consume the same VMs/services.
- All structural changes in I1 avoid code/behavior edits; renames (e.g., `LiveSessionModel` → `LiveSessionViewModel`) are deferred to I3.
