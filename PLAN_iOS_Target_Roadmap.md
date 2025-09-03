## RefWatch iOS Target and Shared Code Roadmap

### Purpose
Establish a clean, scalable iOS structure that mirrors the watchOS feature‑first approach, and define a practical path to share domain models, services, and (where feasible) ViewModels between the two targets. This plan executes on the existing `feature/ios-app-target` branch and proceeds in small, reviewable PRs.

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

PR I1 — iOS Skeleton & Folder Structure (structure only)
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

PR I2 — Share Models and Services (Phase A)
- Goals: Add iOS target membership to shared models and services from watchOS; remove any platform imports from these files if discovered.
- Acceptance: Both targets compile against the same source files for domain/services; no behavioral change on watchOS.

PR I3 — Platform Adapters + Begin Sharing ViewModels
- Goals: Introduce adapter protocols (`HapticsProviding`, `PersistenceProviding`, `ConnectivitySyncProviding`), extract UI‑agnostic parts of key VMs and inject adapters.
- Acceptance: watchOS uses Watch‑specific adapters; iOS uses iOS equivalents; derived labels/timing stay identical.

PR I4 — Extract `RefWatchCore` Swift Package (Phase B)
- Goals: Move shared domain/services/VMs into SPM; migrate unit tests into package tests.
- Acceptance: Both apps depend on the package; `xcodebuild test` runs package tests.

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

