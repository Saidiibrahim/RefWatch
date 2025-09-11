//
//  MatchLifecycleCoordinatorTests.swift
//  RefWatch Watch AppTests
//

import Testing
@testable import RefZone_Watch_App

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
}
