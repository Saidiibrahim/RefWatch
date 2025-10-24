//
//  AggregateSyncCoordinator.swift
//  RefZoneiOS
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
    var queuedAcknowledgedDeltaCount: Int { lastAcknowledgedChangeIds.count }
    var acknowledgedChangeIdsProvider: () -> [UUID]

    init(
        teamStore: TeamLibraryStoring,
        competitionStore: CompetitionLibraryStoring,
        venueStore: VenueLibraryStoring,
        scheduleStore: ScheduleStoring,
        historyStore: MatchHistoryStoring,
        auth: SupabaseAuthStateProviding,
        client: IOSConnectivitySyncClient,
        builder: AggregateSnapshotBuilder = AggregateSnapshotBuilder(),
        acknowledgedChangeIdsProvider: @escaping () -> [UUID] = { [] }
    ) {
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
        historyObserver = NotificationCenter.default.addObserver(
            forName: .matchHistoryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Debounce snapshot refreshes to avoid rapid rebuilds
            self?.snapshotRefreshTask?.cancel()
            self?.snapshotRefreshTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self?.requestSnapshotRefresh()
            }
        }

        client.setManualSyncRequestHandler { [weak self] request in
            guard let self else { return }
            Task { await self.handleManualSyncRequest(request) }
        }
        triggerSnapshotRefresh()
    }

    func stop() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Cancel any pending debounced snapshot refresh
        snapshotRefreshTask?.cancel()
        snapshotRefreshTask = nil

        // Remove NotificationCenter observer to prevent leak
        if let observer = historyObserver {
            NotificationCenter.default.removeObserver(observer)
            historyObserver = nil
        }

        client.setManualSyncRequestHandler(nil)
    }

    func requestSnapshotRefresh() {
        triggerSnapshotRefresh()
    }

    func manualSync(reason: ManualSyncRequestMessage.Reason) async {
        guard case .signedIn = auth.state else { return }
        sendManualStatusUpdate()

        do {
            try await teamStore.refreshFromRemote()
            try await competitionStore.refreshFromRemote()
            try await venueStore.refreshFromRemote()
            try await scheduleStore.refreshFromRemote()
            lastSupabaseRefresh = Date()
            triggerSnapshotRefresh()
            sendManualStatusUpdate()
        } catch {
            NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                "error": error.localizedDescription,
                "context": "ios.aggregate.manualSync"
            ])
        }
    }
}

private extension AggregateSyncCoordinator {
    func sendManualStatusUpdate() {
        // Query real-time status from client instead of using cached coordinator values.
        // This ensures the watch receives accurate pending counts after transfers complete.
        let queueStatus = client.currentSnapshotQueueStatus()
        client.sendManualSyncStatus(
            ManualSyncStatusMessage(
                reachable: client.reachabilityStatus() == .reachable,
                queued: queueStatus.queuedSnapshots,
                queuedDeltas: queueStatus.queuedDeltas,
                pendingSnapshotChunks: queueStatus.pendingChunks,
                lastSnapshot: lastSnapshotAt
            )
        )
    }

    func subscribeToStores() {
        let teamsPublisher = teamStore.changesPublisher
            .prepend((try? teamStore.loadAllTeams()) ?? [])
            .eraseToAnyPublisher()

        let competitionsPublisher = competitionStore.changesPublisher
            .prepend((try? competitionStore.loadAll()) ?? [])
            .eraseToAnyPublisher()

        let venuesPublisher = venueStore.changesPublisher
            .prepend((try? venueStore.loadAll()) ?? [])
            .eraseToAnyPublisher()

        let schedulesPublisher = scheduleStore.changesPublisher
            .prepend(scheduleStore.loadAll())
            .eraseToAnyPublisher()

        Publishers.CombineLatest4(teamsPublisher, competitionsPublisher, venuesPublisher, schedulesPublisher)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] teams, competitions, venues, schedules in
                guard let self else { return }
                self.buildSnapshot(
                    teams: teams,
                    competitions: competitions,
                    venues: venues,
                    schedules: schedules
                )
            }
            .store(in: &cancellables)
    }

    func buildSnapshot(
        teams: [TeamRecord],
        competitions: [CompetitionRecord],
        venues: [VenueRecord],
        schedules: [ScheduledMatch]
    ) {
        guard case .signedIn = auth.state else { return }
        let generatedAt = Date()
        let ackIds = acknowledgedChangeIdsProvider()
        lastAcknowledgedChangeIds = ackIds
        let settings = AggregateSnapshotPayload.Settings(
            connectivityStatus: client.reachabilityStatus(),
            lastSuccessfulSupabaseSync: lastSupabaseRefresh,
            requiresBackfill: ackIds.isEmpty == false || lastSnapshotChunkCount > 1
        )

        // Build bounded history summaries (last 90 days or up to 100 items)
        let recent = ((try? historyStore.loadAll()) ?? [])
            .filter { $0.completedAt >= Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date.distantPast }
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
                venueName: snap.match.venueName
            )
        }

        let payloads = builder.makeSnapshots(
            teams: teams,
            competitions: competitions,
            venues: venues,
            schedules: schedules,
            history: summaries,
            acknowledgedChangeIds: ackIds,
            generatedAt: generatedAt,
            lastSyncedAt: lastSnapshotAt,
            settings: settings
        )

        lastSnapshotChunkCount = payloads.count
        lastSnapshotAt = generatedAt
        client.enqueueAggregateSnapshots(payloads)
    }

    func triggerSnapshotRefresh() {
        let current = (
            teams: (try? teamStore.loadAllTeams()) ?? [],
            competitions: (try? competitionStore.loadAll()) ?? [],
            venues: (try? venueStore.loadAll()) ?? [],
            schedules: scheduleStore.loadAll()
        )
        buildSnapshot(
            teams: current.teams,
            competitions: current.competitions,
            venues: current.venues,
            schedules: current.schedules
        )
    }

    func handleManualSyncRequest(_ request: ManualSyncRequestMessage) async {
        await manualSync(reason: request.reason)
    }
}
