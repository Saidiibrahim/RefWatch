import XCTest
@testable import RefWatchCore

@MainActor
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

    func test_goal_sets_pending_confirmation() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        XCTAssertNil(vm.pendingConfirmation)

        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)

        guard let confirmation = vm.pendingConfirmation else {
            return XCTFail("Expected pending confirmation after recording goal")
        }

        switch confirmation.event.eventType {
        case .goal(let details):
            XCTAssertEqual(details.goalType, .regular)
        default:
            XCTFail("Expected goal event in pending confirmation")
        }
        XCTAssertEqual(confirmation.event.team, .home)

        await vm.clearPendingConfirmation(id: confirmation.id)
        XCTAssertNil(vm.pendingConfirmation)
    }

    func test_undo_goal_reverts_score_and_history() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        let eventCount = vm.matchEvents.count

        XCTAssertTrue(vm.undoLastUserEvent())
        XCTAssertEqual(vm.currentMatch?.homeScore, 0)
        XCTAssertEqual(vm.matchEvents.count, eventCount - 1)
        XCTAssertNil(vm.pendingConfirmation)
    }

    func test_undo_without_events_returns_false() {
        let vm = MatchViewModel()
        XCTAssertFalse(vm.undoLastUserEvent())
    }

    func test_end_current_period_records_period_end_event() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 10, periods: 2, halfTimeLength: 1, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        let initialCount = vm.matchEvents.count

        vm.endCurrentPeriod()

        XCTAssertEqual(periodEndCount(in: vm, period: 1), 1)
        XCTAssertGreaterThan(vm.matchEvents.count, initialCount)
        XCTAssertTrue(vm.isHalfTime)
    }

    func test_natural_period_expiry_notifies_once_and_requires_manual_end() async throws {
        let haptics = HapticsSpy()
        let vm = MatchViewModel(haptics: haptics)
        vm.currentMatch = Match(
            duration: 2,
            numberOfPeriods: 2,
            halfTimeLength: 1,
            hasExtraTime: false,
            hasPenalties: false
        )

        vm.startMatch()

        let reachedBoundary = await waitUntil(timeoutSeconds: 3) {
            vm.isPaused
        }
        XCTAssertTrue(reachedBoundary, "Expected boundary callback to pause for manual period end")
        XCTAssertTrue(vm.isMatchInProgress)
        XCTAssertFalse(vm.isHalfTime)
        XCTAssertFalse(vm.waitingForHalfTimeStart)
        XCTAssertEqual(periodEndCount(in: vm, period: 1), 1)
        XCTAssertEqual(haptics.notifyCount, 1)

        let boundaryMatchTime = parseMMSS(vm.matchTime)
        try await Task.sleep(nanoseconds: 1_100_000_000)
        let laterMatchTime = parseMMSS(vm.matchTime)
        XCTAssertGreaterThan(laterMatchTime, boundaryMatchTime, "Match timer should continue after boundary signal")

        vm.endCurrentPeriod()
        XCTAssertEqual(periodEndCount(in: vm, period: 1), 1, "Manual end should not duplicate periodEnd")
        XCTAssertTrue(vm.isHalfTime)
    }

    func test_end_current_period_does_not_duplicate_period_end_when_later_events_exist() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 10, periods: 2, halfTimeLength: 1, hasExtraTime: false, hasPenalties: false)
        vm.startMatch()

        vm.recordMatchEvent(.periodEnd(1))
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)

        vm.endCurrentPeriod()

        XCTAssertEqual(periodEndCount(in: vm, period: 1), 1)
    }

    func test_createMatch_resets_events_after_finalize() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.createMatch()
        vm.startMatch()
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        XCTAssertFalse(vm.matchEvents.isEmpty)

        vm.finalizeMatch()
        XCTAssertFalse(vm.matchEvents.isEmpty, "Finalize does not clear events by design")

        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()

        XCTAssertTrue(vm.matchEvents.isEmpty, "Starting a new match should clear prior events")
        XCTAssertEqual(vm.currentPeriod, 1)
        XCTAssertFalse(vm.isMatchInProgress)
        XCTAssertNil(vm.pendingConfirmation)
    }
}

private extension MatchViewModel_EventsAndStoppageTests {
    func periodEndCount(in vm: MatchViewModel, period: Int) -> Int {
        vm.matchEvents.reduce(into: 0) { count, event in
            if case .periodEnd(let endedPeriod) = event.eventType, endedPeriod == period {
                count += 1
            }
        }
    }

    func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping () -> Bool) async -> Bool {
        let timeoutNanos = UInt64(timeoutSeconds * 1_000_000_000)
        let stepNanos: UInt64 = 100_000_000
        var elapsedNanos: UInt64 = 0

        while elapsedNanos < timeoutNanos {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: stepNanos)
            elapsedNanos += stepNanos
        }

        return condition()
    }
}

private final class HapticsSpy: HapticsProviding {
    private(set) var notifyCount: Int = 0

    func play(_ event: HapticEvent) {
        if case .notify = event {
            notifyCount += 1
        }
    }
}
