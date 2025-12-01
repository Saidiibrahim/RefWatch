import XCTest
@testable import RefWatchCore

@MainActor
private final class MockMatchHistoryService: MatchHistoryStoring {
    var saved: [CompletedMatch] = []
    func loadAll() throws -> [CompletedMatch] { saved }
    func save(_ match: CompletedMatch) throws { saved.append(match) }
    func delete(id: UUID) throws { saved.removeAll { $0.id == id } }
    func wipeAll() throws { saved.removeAll() }
}

@MainActor
final class MatchViewModel_PersistenceTests: XCTestCase {

    func test_finalizeMatch_persists_snapshot_and_clears_state() async throws {
        let mock = MockMatchHistoryService()
        let vm = MatchViewModel(history: mock)

        vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        vm.finalizeMatch()

        XCTAssertEqual(mock.saved.count, 1)
        if let snap = mock.saved.first {
            XCTAssertEqual(snap.match.homeScore, 1)
            XCTAssertEqual(snap.match.awayScore, 0)
            XCTAssertEqual(snap.events.last?.eventType.displayName, "Match End")
        }
        XCTAssertNil(vm.currentMatch)
    }

    @MainActor
    private final class FailingMatchHistoryService: MatchHistoryStoring {
        func loadAll() throws -> [CompletedMatch] { [] }
        func save(_ match: CompletedMatch) throws { throw NSError(domain: "test", code: -1) }
        func delete(id: UUID) throws { }
        func wipeAll() throws { }
    }

    func test_finalizeMatch_surfaces_error_on_save_failure() async throws {
        let vm = MatchViewModel(history: FailingMatchHistoryService())

        vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()
        vm.finalizeMatch()

        XCTAssertNotNil(vm.lastPersistenceError)
        XCTAssertNil(vm.currentMatch)
    }
}
