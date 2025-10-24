# PLAN_watch_sync_cleanup

## Purpose / Big Picture

Restore bi-directional match sync so referees always see their scheduled and completed matches on both watchOS and iOS. After the changes, creating a match schedule on iOS should surface it in the watch `SavedMatchesListView`, and finishing a match on iOS should populate the watch history list without manual intervention.

## Suprises & Discoveries

- Observation: Watch match history still persists completed matches via JSON instead of SwiftData.
  - Evidence: `MatchRootView` initializes `MatchViewModel` with the default `MatchHistoryService()` (`RefZoneWatchOS/App/MatchRootView.swift:30`), and `MatchHistoryService` writes to `completed_matches.json` in the documents directory (`RefWatchCore/Sources/RefWatchCore/Services/MatchHistoryService.swift`).

## Decision Log

- None yet.

## Outcomes & Retrospective

- Pending implementation.

## Context and Orientation

Current beta feedback shows two gaps in the watch/iOS sync pipeline:

- `RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift` collects upcoming matches into `savedMatches`, but watch testers do not receive schedules created on iOS.
- `RefZoneWatchOS/Features/Match/Views/MatchHistoryView.swift` only displays matches finalized on the watch because iOS completions never reach the watch history store.
- The cross-device pipeline spans `RefZoneiOS/Core/Platform/Connectivity/IOSConnectivitySyncClient.swift`, `RefZoneiOS/Core/Platform/Connectivity/AggregateSyncCoordinator.swift`, and watch counterparts in `RefZoneWatchOS/Core/Platform/Connectivity/WatchConnectivitySyncClient.swift` and `RefZoneWatchOS/Core/Platform/Connectivity/WatchAggregateSyncCoordinator.swift`.

The fix likely involves enabling completed match payloads to flow from iOS to watch, ensuring iOS pushes schedule snapshots promptly, and confirming the watch converts incoming snapshot data into `savedMatches`.

## Plan of Work

1. Audit the current schedule sync pipeline end-to-end, verifying that iOS emits snapshot payloads containing newly created schedules and that the watch receives and stores them in `MatchViewModel.savedMatches`.
2. Implement any missing iOS triggers (e.g., forcing snapshot flushes after schedule changes) and tighten watch-side filtering so remote schedules appear in `SavedMatchesListView`.
3. Wire iOS completions into the WatchConnectivity client by having `IOSConnectivitySyncClient` adopt `ConnectivitySyncProviding`, then pass it into `MatchViewModel` so `finalizeMatch()` emits `"completedMatch"` payloads.
4. Update the watch connectivity client to decode `"completedMatch"` payloads, persist them via `MatchHistoryService`, and update any linked schedules, ensuring `MatchHistoryView` reflects newly synced completions.
5. Add unit/integration tests covering both paths plus lightweight diagnostics to verify the pipelines stay healthy.

## Progress

- [ ] (TASK_01_watch_sync_cleanup.md) Pending – Run instrumentation to trace schedule sync path.
- [ ] (TASK_02_watch_sync_cleanup.md) Pending – Patch schedule snapshot delivery and saved match filtering.
- [ ] (TASK_03_watch_sync_cleanup.md) Pending – Enable iOS completed match push to WatchConnectivity.
- [ ] (TASK_04_watch_sync_cleanup.md) Pending – Persist incoming completed matches on watch & refresh history.
- [ ] (TASK_05_watch_sync_cleanup.md) Pending – Add regression tests and diagnostics cleanup.

## Testing Approach

- Extend unit tests for `AggregateSnapshotBuilder` and `MatchViewModel.updateLibrary`.
- Add watch-side tests to cover schedule ingestion and completed match persistence.
- Introduce iOS-side tests for `IOSConnectivitySyncClient.sendCompletedMatch`.
- Perform manual beta validation: create scheduled match on iOS, confirm watch displays it; finish a match on iOS, confirm watch history updates post-sync.

## Constraints & Considerations

- Keep WatchConnectivity payloads idempotent—guard against duplicate completions when both `sendMessage` and `transferUserInfo` fire.
- Preserve existing watch-offline behavior by falling back to durable transfers when `WCSession` is unreachable.
- Respect scheduling filters (no regressions in kick-off grace window logic) while allowing legitimate remote schedules through.
