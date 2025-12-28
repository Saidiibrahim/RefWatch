<!-- 42c2b8cc-ac4c-411c-8f71-c12da9ae6e37 05d2d18e-2131-4929-9a78-ccf2c516683d -->
# Watch ↔ iPhone Match Sync Fix Plan

### Goals

- Ensure upcoming matches created on iPhone appear in watch `SavedMatchesListView`.
- Show a bounded set of completed matches on watch `MatchHistoryView`, including matches completed on iPhone.
- Use WatchConnectivity only (no Supabase on watch). Show a bounded window (e.g., last 90 days or last 100 items).

### Current findings (key references)

- Watch "Saved Matches" renders what `MatchViewModel.savedMatches` provides; it already listens for aggregate library snapshots:
```124:132:RefWatchWatchOS/App/MatchRootView.swift
.task { matchViewModel.updateLibrary(with: aggregateEnvironment.librarySnapshot) }
.onReceive(aggregateEnvironment.$librarySnapshot) { snapshot in
  matchViewModel.updateLibrary(with: snapshot)
}
```

- iOS builds aggregate snapshots (teams, competitions, venues, schedules) and sends them to the watch:
```137:167:RefWatchiOS/Core/Platform/Connectivity/AggregateSyncCoordinator.swift
func buildSnapshot(teams:..., competitions:..., venues:..., schedules:...) {
  let payloads = builder.makeSnapshots(...)
  client.enqueueAggregateSnapshots(payloads)
}
```

- Watch ingests aggregate snapshots and persists schedules in SwiftData, which feed `MatchLibrarySnapshot` used by `MatchViewModel.updateLibrary`.
- Watch history list uses only local JSON (`MatchHistoryService`) and doesn’t pull iPhone history:
```51:53:RefWatchWatchOS/Features/Match/Views/MatchHistoryView.swift
private func reload() {
  items = matchViewModel.loadRecentCompletedMatches()
}
```


### Root causes

- Upcoming iOS schedules sometimes don’t reach the watch immediately: snapshot refresh may not be triggered on iOS after schedule create/update; manual sync is not surfaced in watch UI.
- Watch history shows only locally completed matches; there’s no inbound path for iPhone-completed matches.

### Design decisions

- Use the existing aggregate snapshot channel to also include a lightweight history summary list (bounded), not full event payloads.
- Add a visible manual Sync action on watch to request a snapshot refresh from iOS.
- Keep the watch history UI read-only for iPhone-completed entries; show essential fields only.

### Implementation plan

1) iOS: Make sure schedules push to watch promptly

- Wire `AggregateSyncCoordinator` to snapshot on schedule changes and manual requests.
  - Confirm/extend `subscribeToStores()` so local create/update in `ScheduleStoring` triggers `triggerSnapshotRefresh()`.
  - On history changes, also refresh snapshot (see below).
  - Files:
    - `RefWatchiOS/Core/Platform/Connectivity/AggregateSyncCoordinator.swift`
    - `RefWatchiOS/Core/Platform/Connectivity/ConnectivitySyncController.swift`

2) iOS: Include a bounded history summary in aggregate snapshots

- Extend snapshot payload to carry `historySummaries: [HistorySummary]` with minimal fields: `id`, `completedAt`, teams, scores, competition, venue (no events).
- Limit to last N (e.g., 100) or last 90 days.
- Hook into history change notifications to rebuild snapshots:
  - `IOSConnectivitySyncClient` posts `.matchHistoryDidChange` after ingest; listen and call `requestSnapshotRefresh()`.
- Files:
  - `RefWatchCore/Sources/RefWatchCore/Domain/AggregateSyncPayloads.swift` (add `HistorySummary` model in core payloads)
  - `RefWatchiOS/Core/Platform/Connectivity/AggregateSnapshotBuilder.swift` (build history section, respect chunk sizing)
  - `RefWatchiOS/Core/Platform/Connectivity/AggregateSyncCoordinator.swift` (source recent history from `MatchHistoryStoring`)
  - `RefWatchiOS/Core/Platform/Connectivity/IOSConnectivitySyncClient.swift` (ensure `.matchHistoryDidChange` leads to snapshot refresh)

3) Watch: Ingest and persist history summaries

- Add SwiftData model and store methods to persist and read recent history summaries.
- Extend `WatchAggregateSyncCoordinator.ingestSnapshotPayload` to upsert `historySummaries`.
- Files:
  - `RefWatchWatchOS/Core/Persistence/SwiftData/WatchAggregateModels.swift` (new `AggregateHistoryRecord`)
  - `RefWatchWatchOS/Core/Persistence/SwiftData/WatchAggregateDataStores.swift` (CRUD helpers)
  - `RefWatchWatchOS/Core/Platform/Connectivity/WatchAggregateSyncCoordinator.swift` (ingest history)

4) Watch UI: Merge local and inbound history, bounded

- Update watch `MatchHistoryView` to read:
  - Local JSON history via `matchViewModel.loadRecentCompletedMatches(limit:)`.
  - Inbound iOS history from aggregate store (new query via `AggregateSyncEnvironment.libraryStore`).
- Merge, deduplicate by `id`, sort by `completedAt`, bound to limit.
- Indicate source (e.g., small secondary label “from iPhone”).
- Files:
  - `RefWatchWatchOS/Features/Match/Views/MatchHistoryView.swift`

5) Watch UI: Manual sync affordance

- Add a “Sync from iPhone” button in Start screen or History screen overflow; call `aggregateEnvironment.connectivity.requestManualAggregateSync()`.
- Optionally show last sync time/status in a footer using `aggregateEnvironment.status`.
- Files:
  - `RefWatchWatchOS/App/MatchRootView.swift` and/or `RefWatchWatchOS/Features/Match/Views/MatchHistoryView.swift`

6) Bounded window policy

- Implement a constant (shared) limit for history: `max( last 90 days, up to 100 items )`.
- Enforce on iOS builder and watch merging to avoid large payloads.

### Testing

- iOS unit: snapshot builder includes schedules and history summaries within limits; chunking respected.
- iOS integration: creating a schedule triggers snapshot enqueue; posting `.matchHistoryDidChange` triggers refresh.
- Watch unit: ingestion persists schedules and history; environmental snapshot updates call `MatchViewModel.updateLibrary`.
- Watch UI tests: upcoming iOS schedule appears in `SavedMatchesListView`; history shows iPhone-completed entries; manual sync updates lists.

### Telemetry and UX

- Add DEBUG logs around sync trigger points and ingestion counts.
- Optional: small status row on watch “History” showing last sync and number of inbound items.

### Risks and mitigations

- Payload size: keep history summaries minimal; rely on chunking already implemented.
- Data races: main-actor writes to SwiftData stores; gate with @MainActor and serial queues as needed.
- Consistency: deduplicate by UUID; prefer iOS summary when duplicate with local JSON.

### Rules applied

- repo-specific rules: greeting, MVVM feature-first, comments for debuggability during implementation.
- Swift-specific rules: use `@Observable` for VMs, environment for shared state (`AggregateSyncEnvironment`), value types for summaries, async/await only if needed.

### To-dos

- [ ] Trigger snapshot refresh on schedule create/update and manual requests (iOS)
- [ ] Add HistorySummary to payload, build bounded list into snapshots (iOS)
- [ ] On .matchHistoryDidChange, request snapshot refresh (iOS)
- [ ] Persist inbound history summaries in SwiftData (watchOS)
- [ ] Merge local JSON and inbound summaries in MatchHistoryView (watchOS)
- [ ] Add Sync from iPhone button and last-sync status (watchOS)
- [ ] Add unit/integration tests for snapshot builder and refresh hooks (iOS)
- [ ] Add unit/UI tests for watch ingestion and UI merging