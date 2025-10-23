//
//  ConnectivitySyncController.swift
//  RefZoneiOS
//
//  Observable controller that owns the WatchConnectivity client and manages
//  its lifecycle across scene phases.
//

import Foundation
import Combine
import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class ConnectivitySyncController: ObservableObject {
    private let client: IOSConnectivitySyncClient
    private let aggregateCoordinator: AggregateSyncCoordinator
    private let deltaCoordinator: AggregateDeltaHandling
    private let aggregateAckStore: AggregateDeltaAckStoring
    private var cancellables = Set<AnyCancellable>()
    private var isActive = false
    private var externalAckProvider: () -> [UUID] = { [] }

    init(
        history: MatchHistoryStoring,
        auth: SupabaseAuthStateProviding,
        teamStore: TeamLibraryStoring,
        competitionStore: CompetitionLibraryStoring,
        venueStore: VenueLibraryStoring,
        scheduleStore: ScheduleStoring
    ) {
        let mediaHandler = SystemMusicMediaCommandHandler()
        self.client = IOSConnectivitySyncClient(
            history: history,
            auth: auth,
            scheduleStore: scheduleStore,
            mediaHandler: mediaHandler
        )
        self.aggregateCoordinator = AggregateSyncCoordinator(
            teamStore: teamStore,
            competitionStore: competitionStore,
            venueStore: venueStore,
            scheduleStore: scheduleStore,
            auth: auth,
            client: client
        )

        guard
            let teamAggregate = teamStore as? AggregateTeamApplying,
            let competitionAggregate = competitionStore as? AggregateCompetitionApplying,
            let venueAggregate = venueStore as? AggregateVenueApplying,
            let scheduleAggregate = scheduleStore as? AggregateScheduleApplying
        else {
            fatalError("Aggregate delta coordinator requires repositories to conform to Aggregate*Applying")
        }

        let ackStore = AggregateDeltaAckStore()
        self.aggregateAckStore = ackStore
        self.deltaCoordinator = AggregateDeltaCoordinator(
            teamRepository: teamAggregate,
            competitionRepository: competitionAggregate,
            venueRepository: venueAggregate,
            scheduleRepository: scheduleAggregate,
            ackStore: ackStore,
            snapshotRefreshHandler: { [weak aggregateCoordinator] in
                aggregateCoordinator?.requestSnapshotRefresh()
            }
        )

        aggregateCoordinator.acknowledgedChangeIdsProvider = { [weak self] in
            guard let self else { return [] }
            let ackIds = self.aggregateAckStore.drainAckIDs()
            let external = self.externalAckProvider()
            return ackIds + external
        }

        client.setAggregateDeltaHandler(deltaCoordinator)

        client.handleAuthState(auth.state)

        auth.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                client.handleAuthState(state)
                if case .signedIn = state, isActive {
                    client.activate()
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        isActive = true
        client.activate()
        aggregateCoordinator.start()
    }

    func stop() {
        isActive = false
        client.deactivate()
        client.setAggregateDeltaHandler(nil)
        aggregateCoordinator.stop()
    }

    deinit {
        stop()
    }

    func triggerManualAggregateSync(reason: ManualSyncRequestMessage.Reason = .manual) {
        Task {
            await aggregateCoordinator.manualSync(reason: reason)
        }
    }

    func updateAcknowledgedChangeIdsProvider(_ provider: @escaping () -> [UUID]) {
        externalAckProvider = provider
        aggregateCoordinator.acknowledgedChangeIdsProvider = { [weak self] in
            guard let self else { return [] }
            let ackIds = self.aggregateAckStore.drainAckIDs()
            let external = self.externalAckProvider()
            return ackIds + external
        }
    }
}
