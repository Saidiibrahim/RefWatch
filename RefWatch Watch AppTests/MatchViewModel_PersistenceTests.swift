//
//  MatchViewModel_PersistenceTests.swift
//  RefWatch Watch AppTests
//

import Foundation
import Testing
@testable import RefWatch_Watch_App

private final class MockMatchHistoryService: MatchHistoryStoring {
    var saved: [CompletedMatch] = []
    func loadAll() throws -> [CompletedMatch] { saved }
    func save(_ match: CompletedMatch) throws { saved.append(match) }
    func delete(id: UUID) throws { saved.removeAll { $0.id == id } }
    func wipeAll() throws { saved.removeAll() }
}

struct MatchViewModel_PersistenceTests {

    @Test
    func test_finalizeMatch_persists_snapshot_and_clears_state() async throws {
        let mock = MockMatchHistoryService()
        let vm = MatchViewModel(history: mock)

        // Configure and create a new match in VM
        vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()

        // Record one home goal for data
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)

        // Finalize
        vm.finalizeMatch()

        // Verify snapshot saved
        #expect(mock.saved.count == 1)
        if let snap = mock.saved.first {
            #expect(snap.match.homeScore == 1)
            #expect(snap.match.awayScore == 0)
            // last event should be Match End (by display name to avoid case matching)
            #expect(snap.events.last?.eventType.displayName == "Match End")
        }

        // VM should clear current match
        #expect(vm.currentMatch == nil)
    }
}

