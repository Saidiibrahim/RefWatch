# RefWatch watchOS SwiftData Migration Plan

## Purpose
- Migrate watchOS local history from the legacy JSON file (`MatchHistoryService`) to SwiftData with minimal risk and no changes to WatchConnectivity behavior.
- Keep the watch as a lightweight, offline-first producer while maintaining iOS as the richer history/analysis surface.

## Current State
- Watch: Persists completed matches with `MatchHistoryService` (JSON), and sends snapshots to iPhone via `WatchConnectivitySyncClient`.
- iOS: Persists to SwiftData via `SwiftDataMatchHistoryStore`, with one-time import from JSON already implemented.
- VM: `MatchViewModel.finalizeMatch()` saves to `MatchHistoryStoring` and optionally sends the snapshot via `ConnectivitySyncProviding`.

## Goals
- Persist watch history to SwiftData locally (offline-first).
- Perform a one-time import from the legacy JSON file on first run.
- Inject the SwiftData-backed store into the watch app entry without changing feature flows.
- Keep WatchConnectivity behavior unchanged (watch continues to export completed snapshots to iPhone).

## Non-Goals
- No auth UI or identity on watch in this migration.
- No new history UX on watch (listing/filtering/search). This plan focuses on persistence mechanics only.
- No cross-platform refactor to move SwiftData code into the package (can be a follow-up once stable).

## Constraints & Assumptions
- SwiftData requires watchOS 10+. If the current deployment target is < 10, we must either raise it or keep JSON on older OS versions (graceful fallback).
- Maintain binary size and runtime costs low on watch; use simple queries and avoid heavy indexing.

## Approach Overview
1) Add a watch-specific SwiftData model and store that conform to `MatchHistoryStoring`.
2) On store init, import all items from `MatchHistoryService` JSON once (de-dupe by `id`), then persist only to SwiftData going forward.
3) Post the same `matchHistoryDidChange` notification after mutations to keep any listeners in sync (mirrors iOS behavior).
4) Wire the store in the watch app entry so `MatchViewModel` receives the SwiftData-backed store.
5) Keep WatchConnectivity sender unchanged; VM still calls `connectivity?.sendCompletedMatch()` on finalize.

## Data Model
- Reuse the same conceptual shape as iOS:
  - `CompletedMatchRecord` with fields:
    - `id: UUID` (unique)
    - `completedAt: Date`
    - `ownerId: String?` (optional, future-ready; may remain nil on watch)
    - Lightweight list fields: `homeTeam`, `awayTeam`, `homeScore`, `awayScore`
    - `payload: Data` (full `CompletedMatch` encoded as JSON for fidelity)
- Minimal risk path: keep a watch-local copy of this model under watch sources. Future improvement: extract a shared model to `RefWatchCore` or the SPM package when appropriate.

## Store Responsibilities (watch)
- Type: `SwiftDataMatchHistoryStore` (watch variant) conforming to `MatchHistoryStoring`.
- Methods:
  - `loadAll()` → fetch all `CompletedMatchRecord` sorted by `completedAt desc`, decode `payload` into `[CompletedMatch]`.
  - `save(_:)` → upsert by `id` and `context.save()`.
  - `delete(id:)` and `wipeAll()` → mutate and `context.save()`.
  - Post `.matchHistoryDidChange` after `save/delete/wipeAll`.
- Import on first run:
  - Flag in `UserDefaults` (watch-specific key, e.g., `rw_watch_history_imported_v1`).
  - Read `(try? MatchHistoryService().loadAll()) ?? []`, skip if empty.
  - De-dupe against existing SwiftData records by `id`.
  - Save each; mark the flag true when complete.
- Actor/Threading:
  - Annotate the store `@MainActor` to align with SwiftUI and avoid threading pitfalls on watch.

## Wiring
- Build a `ModelContainer` for the watch schema (`[CompletedMatchRecord.self]`).
- Construct the watch `SwiftDataMatchHistoryStore` with the container; pass into `MatchViewModel(history: store, haptics: WatchHaptics(), connectivity: WatchConnectivitySyncClient())`.
- Location:
  - Model + store: `RefZoneWatchOS/Core/Persistence/SwiftData/` (new folder).
  - App entry wiring: `RefZoneWatchOS/App/MatchRootView.swift` or app `@main` entry depending on current composition.

## WatchConnectivity (Unchanged)
- Keep `WatchConnectivitySyncClient` as-is. VM continues to send snapshots on finalize.
- iOS receiver already merges by `id` and posts `.matchHistoryDidChange`.

## Rollout Strategy
- Phase W1 — Add SwiftData Model + Store
  - Add `CompletedMatchRecord` (watch) and `SwiftDataMatchHistoryStore` (watch) with de-dupe logic and notifications.
  - Add unit tests with in-memory `ModelContainer` for round-trip, upsert, and import.
- Phase W2 — Wire + Import
  - Build `ModelContainer` in watch app entry.
  - Inject the SwiftData store into `MatchViewModel`.
  - Enable one-time import from JSON on first run.
  - Verify end-to-end: start → finish → re-open app → history remains.
- Phase W3 — Cleanup + Docs
  - Confirm no call sites rely on JSON after import.
  - Keep `MatchHistoryService` available for tests or fallback; do not delete yet.
  - Document the migration and rollback steps.

## Acceptance Criteria
- Completing a match on watch persists to SwiftData and survives app relaunch.
- First-run import migrates existing JSON history into SwiftData without duplicates.
- Watch continues to export completed snapshots to iPhone; iOS History shows the new item.
- No crashes on devices without paired iPhone; behavior remains offline-first.

## Testing & Verification
- Unit tests (watch target or shared test bundle using watch schema):
  - `testSaveAndLoad_roundTrip()` with in-memory container.
  - `testUpsert_dedupesById()` to ensure id-based overwrite.
  - `testImportFromLegacyJSON_setsImportFlag()` using a temporary JSON file and a test-specific `UserDefaults` suite.
- Manual checks on simulator/device:
  - Start/finish a match; confirm History (if surfaced) or confirm on iOS via sync.
  - Relaunch watch app; confirm persistence.
  - Turn off iPhone; confirm no crashes, local store still functions.

## Risks & Mitigations
- Deployment target < watchOS 10: Mitigate by gating SwiftData to 10+, fallback to JSON for older OS versions, or raise the minimum.
- Storage bloat: Use compact fields for list UI and keep full JSON snapshot in `payload`; purge/wipe remains available.
- Concurrency issues: `@MainActor` store + simple fetch descriptors.
- Duplicate imports: Use a persistent flag and prefetch existing `id`s before import.

## Rollback Plan
- Feature flag the new store (build-time or runtime). If issues arise, switch back to `MatchHistoryService` (JSON) while keeping the SwiftData code disabled.
- The import is additive; JSON remains untouched. No destructive migration is performed in this plan.

## Follow-ups (Optional)
- Unify SwiftData model/store in `RefWatchCore` or the `RefWatchCore` package to eliminate duplication.
- Consider adding a lightweight History list on watch if product needs grow.
- Introduce an auth-aware adapter later (e.g., set `ownerId` when available) to align with iOS behavior.

## References
- JSON service: `RefWatchCore/Sources/RefWatchCore/Services/MatchHistoryService.swift`
- iOS model: `RefZoneiOS/Core/Persistence/SwiftData/CompletedMatchRecord.swift`
- iOS store: `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataMatchHistoryStore.swift`
- VM finalize + connectivity: `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift`
- Watch connectivity: `RefZoneWatchOS/Core/Platform/Connectivity/WatchConnectivitySyncClient.swift`
