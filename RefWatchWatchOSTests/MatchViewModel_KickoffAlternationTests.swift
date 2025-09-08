//
//  MatchViewModel_KickoffAlternationTests.swift
//  RefWatch Watch AppTests
//

import Testing
@testable import RefWatch_Watch_App

struct MatchViewModel_KickoffAlternationTests {

    @Test func test_second_half_kicking_team_is_opposite() async throws {
        let vm = MatchViewModel()

        vm.setKickingTeam(true) // home kicked off first half
        #expect(vm.getSecondHalfKickingTeam() == .away)

        vm.setKickingTeam(false) // away kicked off first half
        #expect(vm.getSecondHalfKickingTeam() == .home)
    }
}
