import XCTest
@testable import RefWatchCore

final class MatchViewModel_EventsAndStoppageTests: XCTestCase {

    func test_event_order_after_start_and_goal() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        XCTAssertGreaterThanOrEqual(vm.matchEvents.count, 2)
        if vm.matchEvents.count >= 2 {
            switch vm.matchEvents[0].eventType {
            case .kickOff: break
            default: XCTFail("First event should be kickOff")
            }
            switch vm.matchEvents[1].eventType {
            case .periodStart(let p):
                XCTAssertEqual(p, 1)
            default:
                XCTFail("Second event should be periodStart(1)")
            }
        }

        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        guard let last = vm.matchEvents.last else { return XCTFail("Expected last event") }
        switch last.eventType {
        case .goal(let details):
            XCTAssertEqual(details.goalType, .regular)
            XCTAssertEqual(last.team, .home)
        default:
            XCTFail("Last event should be a regular goal for home")
        }
    }

    func test_regular_and_own_goal_scoring_updates_correct_side() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.startMatch()

        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        XCTAssertEqual(vm.currentMatch?.homeScore, 1)
        XCTAssertEqual(vm.currentMatch?.awayScore, 0)

        vm.recordGoal(team: .away, goalType: .ownGoal, playerNumber: 5)
        XCTAssertEqual(vm.currentMatch?.homeScore, 1)
        XCTAssertEqual(vm.currentMatch?.awayScore, 1)
    }

    func test_stoppage_accumulates_across_pauses() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        vm.pauseMatch()
        try await Task.sleep(nanoseconds: 1_200_000_000)
        vm.resumeMatch()
        let first = parseMMSS(vm.formattedStoppageTime)
        XCTAssertGreaterThanOrEqual(first, 1)

        vm.pauseMatch()
        try await Task.sleep(nanoseconds: 1_100_000_000)
        vm.resumeMatch()
        let second = parseMMSS(vm.formattedStoppageTime)
        XCTAssertGreaterThanOrEqual(second, 2)
    }
}

