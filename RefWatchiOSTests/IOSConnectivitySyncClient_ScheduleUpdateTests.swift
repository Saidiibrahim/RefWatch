import Foundation
import Testing
@testable import RefWatchiOS
import RefWatchCore

@MainActor
@Suite("IOSConnectivitySyncClient Schedule Updates")
struct IOSConnectivitySyncClientScheduleUpdateTests {

    @Test("Marks schedule completed when match with scheduledMatchId arrives")
    func marksScheduleCompleted() async throws {
        let history = MockHistoryStore()
        let scheduleStore = InMemoryScheduleStore()
        let auth = MutableAuth(state: .signedIn(userId: "test", email: nil, displayName: nil))

        let scheduleId = UUID()
        let schedule = ScheduledMatch(
            id: scheduleId,
            homeTeam: "Team A",
            awayTeam: "Team B",
            kickoff: Date(),
            status: .scheduled
        )
        try scheduleStore.save(schedule)

        let client = IOSConnectivitySyncClient(history: history, auth: auth, scheduleStore: scheduleStore)
        client.handleAuthState(auth.state)

        // CRITICAL: Set scheduledMatchId to link match to schedule
        var match = Match(homeTeam: "Team A", awayTeam: "Team B")
        match.scheduledMatchId = scheduleId
        let completed = CompletedMatch(match: match, events: [])
        client.handleCompletedMatch(completed)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        let updated = scheduleStore.loadAll().first { $0.id == scheduleId }
        #expect(updated?.status == .completed)
        #expect(history.saved.count == 1)
    }

    @Test("Doesn't crash when schedule missing")
    func handlesMissingSchedule() async throws {
        let history = MockHistoryStore()
        let scheduleStore = InMemoryScheduleStore()
        let auth = MutableAuth(state: .signedIn(userId: "test", email: nil, displayName: nil))

        let client = IOSConnectivitySyncClient(history: history, auth: auth, scheduleStore: scheduleStore)
        client.handleAuthState(auth.state)

        // Match with scheduledMatchId that doesn't exist in store
        var match = Match(homeTeam: "Watch Created", awayTeam: "Team")
        match.scheduledMatchId = UUID() // Non-existent schedule
        let completed = CompletedMatch(match: match, events: [])
        client.handleCompletedMatch(completed)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(history.saved.count == 1)
    }

    @Test("Manual match without scheduledMatchId doesn't crash")
    func handlesManualMatch() async throws {
        let history = MockHistoryStore()
        let scheduleStore = InMemoryScheduleStore()
        let auth = MutableAuth(state: .signedIn(userId: "test", email: nil, displayName: nil))

        let client = IOSConnectivitySyncClient(history: history, auth: auth, scheduleStore: scheduleStore)
        client.handleAuthState(auth.state)

        // Manual match without scheduledMatchId
        let match = Match(homeTeam: "Manual Match", awayTeam: "Team")
        // scheduledMatchId is nil
        let completed = CompletedMatch(match: match, events: [])
        client.handleCompletedMatch(completed)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Should save to history but not try to update any schedule
        #expect(history.saved.count == 1)
        #expect(scheduleStore.loadAll().isEmpty) // No schedules added
    }

    @Test("Preserves scheduledMatchId when saving to history")
    func preservesScheduledMatchId() async throws {
        let history = MockHistoryStore()
        let scheduleStore = InMemoryScheduleStore()
        let auth = MutableAuth(state: .signedIn(userId: "test", email: nil, displayName: nil))

        let scheduleId = UUID()
        let schedule = ScheduledMatch(
            id: scheduleId,
            homeTeam: "Team A",
            awayTeam: "Team B",
            kickoff: Date(),
            status: .scheduled
        )
        try scheduleStore.save(schedule)

        let client = IOSConnectivitySyncClient(history: history, auth: auth, scheduleStore: scheduleStore)
        client.handleAuthState(auth.state)

        var match = Match(homeTeam: "Team A", awayTeam: "Team B")
        match.scheduledMatchId = scheduleId
        let completed = CompletedMatch(match: match, events: [])
        client.handleCompletedMatch(completed)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(history.saved.count == 1)
        #expect(history.saved.first?.scheduledMatchId == scheduleId)
    }
}

@MainActor
private final class MockHistoryStore: MatchHistoryStoring {
    private(set) var saved: [CompletedMatch] = []

    func loadAll() throws -> [CompletedMatch] { saved }
    func save(_ match: CompletedMatch) throws { saved.append(match) }
    func delete(id: UUID) throws { saved.removeAll { $0.id == id } }
    func wipeAll() throws { saved.removeAll() }
}

@MainActor
private final class MutableAuth: AuthenticationProviding {
    private var backingState: AuthState

    init(state: AuthState) {
        self.backingState = state
    }

    var state: AuthState { backingState }

    var currentUserId: String? {
        if case let .signedIn(userId, _, _) = backingState {
            return userId
        }
        return nil
    }

    var currentEmail: String? { nil }
    var currentDisplayName: String? { nil }

    func updateState(_ state: AuthState) {
        backingState = state
    }
}
