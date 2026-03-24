//
//  MatchLifecycleCoordinatorTests.swift
//  RefWatch Watch AppTests
//

import Testing
import RefWatchCore
@testable import RefWatch_Watch_App

@MainActor
struct MatchLifecycleCoordinatorTests {
    @Test func test_initial_state_is_idle() async throws {
        let lc = MatchLifecycleCoordinator()
        #expect(lc.state == .idle)
    }

    @Test func test_state_transitions() async throws {
        let lc = MatchLifecycleCoordinator()

        lc.goToSetup()
        #expect(lc.state == .setup)

        lc.goToKickoffFirst()
        #expect(lc.state == .kickoffFirstHalf)

        lc.goToKickoffSecond()
        #expect(lc.state == .kickoffSecondHalf)

        lc.goToFinished()
        #expect(lc.state == .finished)

        lc.resetToStart()
        #expect(lc.state == .idle)
    }

    @Test func test_goToKickoffFirst_is_idempotent() async throws {
        let lc = MatchLifecycleCoordinator()

        lc.goToKickoffFirst()
        lc.goToKickoffFirst()

        #expect(lc.state == .kickoffFirstHalf)
    }

    @Test func test_resumedState_routesWaitingHalfTimeToTimerSurface() async throws {
        let lc = MatchLifecycleCoordinator()

        let state = FakeRoutingState(
            hasCurrentMatch: true,
            waitingForHalfTimeStart: true)

        #expect(lc.resumedState(using: state) == .setup)
    }

    @Test func test_resumedState_routesPendingBoundaryDecisionToTimerSurface() async throws {
        let lc = MatchLifecycleCoordinator()

        let state = FakeRoutingState(
            hasCurrentMatch: true,
            pendingPeriodBoundaryDecision: .firstHalf)

        #expect(lc.resumedState(using: state) == .setup)
    }

    @Test func test_resumedState_routesWaitingPenaltiesToChooseFirstKicker() async throws {
        let lc = MatchLifecycleCoordinator()

        let state = FakeRoutingState(
            hasCurrentMatch: true,
            waitingForPenaltiesStart: true)

        #expect(lc.resumedState(using: state) == .choosePenaltyFirstKicker)
    }

    @Test func test_resumedState_routesActivePenaltiesToPenaltiesSurface() async throws {
        let lc = MatchLifecycleCoordinator()

        let state = FakeRoutingState(
            hasCurrentMatch: true,
            penaltyShootoutActive: true)

        #expect(lc.resumedState(using: state) == .penalties)
    }

    @Test func test_resumedState_routesFullTimePendingCompletionToFinished() async throws {
        let lc = MatchLifecycleCoordinator()

        let state = FakeRoutingState(
            hasCurrentMatch: true,
            isFullTime: true,
            matchCompleted: false)

        #expect(lc.resumedState(using: state) == .finished)
    }
}

@MainActor
private struct FakeRoutingState: MatchLifecycleRoutingState {
    var hasCurrentMatch: Bool = false
    var isMatchInProgress: Bool = false
    var isPaused: Bool = false
    var isHalfTime: Bool = false
    var waitingForMatchStart: Bool = false
    var waitingForHalfTimeStart: Bool = false
    var waitingForSecondHalfStart: Bool = false
    var waitingForET1Start: Bool = false
    var waitingForET2Start: Bool = false
    var waitingForPenaltiesStart: Bool = false
    var pendingPeriodBoundaryDecision: PendingPeriodBoundaryDecision? = nil
    var penaltyShootoutActive: Bool = false
    var isFullTime: Bool = false
    var matchCompleted: Bool = false
}
