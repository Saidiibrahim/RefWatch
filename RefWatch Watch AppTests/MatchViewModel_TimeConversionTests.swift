//
//  MatchViewModel_TimeConversionTests.swift
//  RefWatch Watch AppTests
//

import Testing
@testable import RefWatch_Watch_App

struct MatchViewModel_TimeConversionTests {

    @Test func test_configureMatch_converts_minutes_to_seconds() async throws {
        let vm = MatchViewModel()

        vm.configureMatch(
            duration: 50,
            periods: 2,
            halfTimeLength: 15,
            hasExtraTime: false,
            hasPenalties: false
        )

        #expect(vm.currentMatch != nil)
        #expect(vm.currentMatch?.duration == 50 * 60)
        #expect(vm.currentMatch?.halfTimeLength == 15 * 60)
        #expect(vm.currentMatch?.numberOfPeriods == 2)
    }

    @Test func test_resetMatch_uses_per_period_for_remaining_label() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(
            duration: 50,
            periods: 2,
            halfTimeLength: 10,
            hasExtraTime: false,
            hasPenalties: false
        )

        // After reset, periodTimeRemaining should reflect per-period (25:00)
        vm.resetMatch()
        #expect(vm.periodTimeRemaining == "25:00")
    }

    @Test func test_safe_denominator_when_periods_is_zero() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(
            duration: 40, // 40 minutes total
            periods: 0,   // invalid value to test guard rails
            halfTimeLength: 10,
            hasExtraTime: false,
            hasPenalties: false
        )
        // Should not crash; startMatch should compute per-period using max(1, periods)
        vm.startMatch()
        // Expect per-period remaining to be full duration (40:00)
        #expect(vm.periodTimeRemaining == "40:00")
    }
}
