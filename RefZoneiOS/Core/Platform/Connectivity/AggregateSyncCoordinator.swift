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
    private let auth: SupabaseAuthStateProviding
    private let client: IOSConnectivitySyncClient
    private let builder: AggregateSnapshotBuilder

    private var cancellables = Set<AnyCancellable>()
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
        auth: SupabaseAuthStateProviding,
        client: IOSConnectivitySyncClient,
        builder: AggregateSnapshotBuilder = AggregateSnapshotBuilder(),
        acknowledgedChangeIdsProvider: @escaping () -> [UUID] = { [] }
    ) {
        self.teamStore = teamStore
        self.competitionStore = competitionStore
        self.venueStore = venueStore
        self.scheduleStore = scheduleStore
        self.auth = auth
        self.client = client
        self.builder = builder
        self.acknowledgedChangeIdsProvider = acknowledgedChangeIdsProvider
    }

    func start() {
        subscribeToStores()
        client.setManualSyncRequestHandler { [weak self] request in
            guard let self else { return }
            Task { await self.handleManualSyncRequest(request) }
        }
        triggerSnapshotRefresh()
    }

    func stop() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
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
        client.sendManualSyncStatus(
            ManualSyncStatusMessage(
                reachable: client.reachabilityStatus() == .reachable,
                queued: lastSnapshotChunkCount,
                queuedDeltas: queuedAcknowledgedDeltaCount,
                pendingSnapshotChunks: lastSnapshotChunkCount,
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

        let payloads = builder.makeSnapshots(
            teams: teams,
            competitions: competitions,
            venues: venues,
            schedules: schedules,
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
