import XCTest
import Combine
@testable import RefZoneiOS
import RefWatchCore

@MainActor
final class AggregateSyncCoordinatorTests: XCTestCase {
    func testManualSyncDrainsAcknowledgementsOnce() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let history = MatchHistoryService(baseDirectory: tempDirectory)
        let auth = StubAuth(state: .signedIn(userId: "user-1", email: "user@example.com", displayName: "Test"))
        let teamStore = InMemoryTeamLibraryStore()
        let competitionStore = InMemoryCompetitionLibraryStore()
        let venueStore = InMemoryVenueLibraryStore()
        let scheduleStore = InMemoryScheduleStore()
        let client = IOSConnectivitySyncClient(history: history, auth: auth)

        let coordinator = AggregateSyncCoordinator(
            teamStore: teamStore,
            competitionStore: competitionStore,
            venueStore: venueStore,
            scheduleStore: scheduleStore,
            historyStore: history,
            auth: auth,
            client: client
        )

        coordinator.start()
        try await Task.sleep(nanoseconds: 300_000_000) // allow initial debounce to settle

        var drainCount = 0
        let ackId = UUID()
        coordinator.acknowledgedChangeIdsProvider = {
            drainCount += 1
            return [ackId]
        }

        await coordinator.manualSync(reason: .manual)

        XCTAssertEqual(drainCount, 1, "Acknowledgement provider should be consulted once during manual sync")
        XCTAssertEqual(coordinator.queuedAcknowledgedDeltaCount, 1)

        let mirror = Mirror(reflecting: client)
        guard
            let rawSnapshots = mirror.descendant("aggregateSnapshots") as? [Data],
            let firstSnapshot = rawSnapshots.first
        else {
            XCTFail("Expected encoded aggregate snapshot to be enqueued")
            return
        }

        let decoder = AggregateSyncCoding.makeDecoder()
        let payload = try decoder.decode(AggregateSnapshotPayload.self, from: firstSnapshot)
        XCTAssertEqual(Set(payload.acknowledgedChangeIds), [ackId])
    }
}

@MainActor
private final class StubAuth: SupabaseAuthStateProviding {
    var state: AuthState {
        didSet { subject.send(state) }
    }

    var statePublisher: AnyPublisher<AuthState, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentUserId: String? {
        if case let .signedIn(userId, _, _) = state { return userId }
        return nil
    }

    var currentEmail: String? {
        if case let .signedIn(_, email, _) = state { return email }
        return nil
    }

    var currentDisplayName: String? {
        if case let .signedIn(_, _, name) = state { return name }
        return nil
    }

    private let subject: CurrentValueSubject<AuthState, Never>

    init(state: AuthState) {
        self.state = state
        self.subject = CurrentValueSubject(state)
    }
}
