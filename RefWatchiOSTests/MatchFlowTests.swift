import XCTest
import RefWatchCore
@testable import RefWatchiOS

@MainActor
final class MatchFlowTests: XCTestCase {
    // Creates a VM using a temporary history file location
    private func makeVM() -> (MatchViewModel, MatchHistoryService) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatchFlowTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let history = MatchHistoryService(baseDirectory: base)
        let vm = MatchViewModel(history: history, haptics: NoopHaptics())
        return (vm, history)
    }

    func testCreateAndStart_setsInProgress_andAddsKickoffEvents() {
        let (vm, _) = makeVM()
        vm.newMatch = Match(homeTeam: "Home", awayTeam: "Away")
        vm.createMatch()
        vm.startMatch()

        XCTAssertTrue(vm.isMatchInProgress)
        XCTAssertFalse(vm.matchEvents.isEmpty)
        // Expect kickoff and period start to be part of the first events
        XCTAssertGreaterThanOrEqual(vm.matchEvents.count, 2)
    }

    func testRecordGoal_updatesScore_andAppendsEvent() {
        let (vm, _) = makeVM()
        vm.newMatch = Match(homeTeam: "Home", awayTeam: "Away")
        vm.createMatch()
        vm.startMatch()
        let before = vm.currentMatch?.homeScore ?? -1
        vm.recordGoal(team: .home, goalType: .regular)
        let after = vm.currentMatch?.homeScore ?? -1
        XCTAssertEqual(after, before + 1)
        XCTAssertTrue(vm.matchEvents.contains { if case .goal = $0.eventType { return true } else { return false } })
    }

    func testFinalizeMatch_persistsSnapshot_toHistoryService() throws {
        let (vm, history) = makeVM()
        vm.newMatch = Match(homeTeam: "Home", awayTeam: "Away")
        vm.createMatch()
        vm.startMatch()
        vm.finalizeMatch()

        let all = try history.loadAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.match.homeTeam, "Home")
        XCTAssertEqual(all.first?.match.awayTeam, "Away")
    }
}
