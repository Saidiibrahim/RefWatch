//
//  AggregateSyncCoordinator.swift
//  RefWatchiOS
//
//  Coordinates aggregate library snapshots between iOS and watchOS.
//

import Combine
import Foundation
import RefWatchCore

@MainActor
final class AggregateSyncCoordinator {
  private let teamStore: TeamLibraryStoring
  private let competitionStore: CompetitionLibraryStoring
  private let venueStore: VenueLibraryStoring
  private let scheduleStore: ScheduleStoring
  private let historyStore: MatchHistoryStoring
  private let auth: SupabaseAuthStateProviding
  private let client: IOSConnectivitySyncClient
  private let builder: AggregateSnapshotBuilder

  private var cancellables = Set<AnyCancellable>()
  private var historyObserver: NSObjectProtocol?
  private var snapshotRefreshTask: Task<Void, Never>?
  private var lastSupabaseRefresh: Date?
  private var lastSnapshotAt: Date?
  private var lastSnapshotChunkCount: Int = 0
  private var lastAcknowledgedChangeIds: [UUID] = []
  var queuedAcknowledgedDeltaCount: Int { self.lastAcknowledgedChangeIds.count }
  var acknowledgedChangeIdsProvider: () -> [UUID]

  init(
    teamStore: TeamLibraryStoring,
    competitionStore: CompetitionLibraryStoring,
    venueStore: VenueLibraryStoring,
    scheduleStore: ScheduleStoring,
    historyStore: MatchHistoryStoring,
    auth: SupabaseAuthStateProviding,
    client: IOSConnectivitySyncClient,
    builder: AggregateSnapshotBuilder,
    acknowledgedChangeIdsProvider: @escaping () -> [UUID] = { [] })
  {
    self.teamStore = teamStore
    self.competitionStore = competitionStore
    self.venueStore = venueStore
    self.scheduleStore = scheduleStore
    self.historyStore = historyStore
    self.auth = auth
    self.client = client
    self.builder = builder
    self.acknowledgedChangeIdsProvider = acknowledgedChangeIdsProvider
  }

  func start() {
    subscribeToStores()

    // Remove old observer if exists to prevent duplicates
    if let observer = historyObserver {
      NotificationCenter.default.removeObserver(observer)
    }

    // Store the observer token for cleanup in stop()
    self.historyObserver = NotificationCenter.default.addObserver(
      forName: .matchHistoryDidChange,
      object: nil,
      queue: .main)
    { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        // Debounce snapshot refreshes to avoid rapid rebuilds
        self.snapshotRefreshTask?.cancel()
        self.snapshotRefreshTask = Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(500))
          self.requestSnapshotRefresh()
        }
      }
    }

    self.client.setManualSyncRequestHandler { [weak self] request in
      Task { @MainActor [weak self] in
        guard let self else { return }
        await self.handleManualSyncRequest(request)
      }
    }
    triggerSnapshotRefresh()
  }

  func stop() {
    self.cancellables.forEach { $0.cancel() }
    self.cancellables.removeAll()

    // Cancel any pending debounced snapshot refresh
    self.snapshotRefreshTask?.cancel()
    self.snapshotRefreshTask = nil

    // Remove NotificationCenter observer to prevent leak
    if let observer = historyObserver {
      NotificationCenter.default.removeObserver(observer)
      self.historyObserver = nil
    }

    self.client.setManualSyncRequestHandler(nil)
  }

  func requestSnapshotRefresh() {
    triggerSnapshotRefresh()
  }

  func manualSync(reason: ManualSyncRequestMessage.Reason) async {
    guard case .signedIn = self.auth.state else { return }
    sendManualStatusUpdate()

    do {
      try await self.teamStore.refreshFromRemote()
      try await self.competitionStore.refreshFromRemote()
      try await self.venueStore.refreshFromRemote()
      try await self.scheduleStore.refreshFromRemote()
      self.lastSupabaseRefresh = Date()
      triggerSnapshotRefresh()
      sendManualStatusUpdate()
    } catch {
      NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
        "error": error.localizedDescription,
        "context": "ios.aggregate.manualSync",
      ])
    }
  }
}

extension AggregateSyncCoordinator {
  private func sendManualStatusUpdate() {
    // Query real-time status from client instead of using cached coordinator values.
    // This ensures the watch receives accurate pending counts after transfers complete.
    let queueStatus = self.client.currentSnapshotQueueStatus()
    self.client.sendManualSyncStatus(
      ManualSyncStatusMessage(
        reachable: self.client.reachabilityStatus() == .reachable,
        queued: queueStatus.queuedSnapshots,
        queuedDeltas: queueStatus.queuedDeltas,
        pendingSnapshotChunks: queueStatus.pendingChunks,
        lastSnapshot: self.lastSnapshotAt))
  }

  private func subscribeToStores() {
    let teamsPublisher = self.teamStore.changesPublisher
      .prepend((try? self.teamStore.loadAllTeams()) ?? [])
      .eraseToAnyPublisher()

    let competitionsPublisher = self.competitionStore.changesPublisher
      .prepend((try? self.competitionStore.loadAll()) ?? [])
      .eraseToAnyPublisher()

    let venuesPublisher = self.venueStore.changesPublisher
      .prepend((try? self.venueStore.loadAll()) ?? [])
      .eraseToAnyPublisher()

    let schedulesPublisher = self.scheduleStore.changesPublisher
      .prepend(self.scheduleStore.loadAll())
      .eraseToAnyPublisher()

    Publishers.CombineLatest4(teamsPublisher, competitionsPublisher, venuesPublisher, schedulesPublisher)
      .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
      .sink { [weak self] teams, competitions, venues, schedules in
        guard let self else { return }
        self.buildSnapshot(
          teams: teams,
          competitions: competitions,
          venues: venues,
          schedules: schedules)
      }
      .store(in: &self.cancellables)
  }

  private func buildSnapshot(
    teams: [TeamRecord],
    competitions: [CompetitionRecord],
    venues: [VenueRecord],
    schedules: [ScheduledMatch])
  {
    guard case .signedIn = self.auth.state else { return }
    let generatedAt = Date()
    let ackIds = self.acknowledgedChangeIdsProvider()
    self.lastAcknowledgedChangeIds = ackIds
    let settings = AggregateSnapshotPayload.Settings(
      connectivityStatus: self.client.reachabilityStatus(),
      lastSuccessfulSupabaseSync: self.lastSupabaseRefresh,
      requiresBackfill: ackIds.isEmpty == false || self.lastSnapshotChunkCount > 1)

    // Build bounded history summaries (last 90 days or up to 100 items)
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
    let recent = ((try? self.historyStore.loadAll()) ?? [])
      .filter { $0.completedAt >= cutoffDate }
      .sorted { $0.completedAt > $1.completedAt }
    let limited = Array(recent.prefix(100))
    let summaries: [AggregateSnapshotPayload.HistorySummary] = limited.map { snap in
      AggregateSnapshotPayload.HistorySummary(
        id: snap.id,
        completedAt: snap.completedAt,
        homeName: snap.match.homeTeam,
        awayName: snap.match.awayTeam,
        homeScore: snap.match.homeScore,
        awayScore: snap.match.awayScore,
        competitionName: snap.match.competitionName,
        venueName: snap.match.venueName)
    }

    let payloads = self.builder.makeSnapshots(
      AggregateSnapshotBuilder.SnapshotInputs(
        teams: teams,
        competitions: competitions,
        venues: venues,
        schedules: schedules,
        history: summaries,
        acknowledgedChangeIds: ackIds,
        generatedAt: generatedAt,
        lastSyncedAt: self.lastSnapshotAt,
        settings: settings))

    self.lastSnapshotChunkCount = payloads.count
    self.lastSnapshotAt = generatedAt
    self.client.enqueueAggregateSnapshots(payloads)
  }

  private func triggerSnapshotRefresh() {
    let current = (
      teams: (try? self.teamStore.loadAllTeams()) ?? [],
      competitions: (try? self.competitionStore.loadAll()) ?? [],
      venues: (try? self.venueStore.loadAll()) ?? [],
      schedules: self.scheduleStore.loadAll())
    self.buildSnapshot(
      teams: current.teams,
      competitions: current.competitions,
      venues: current.venues,
      schedules: current.schedules)
  }

  private func handleManualSyncRequest(_ request: ManualSyncRequestMessage) async {
    await self.manualSync(reason: request.reason)
  }
}
