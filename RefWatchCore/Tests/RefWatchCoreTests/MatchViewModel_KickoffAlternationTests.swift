import XCTest
@testable import RefWatchCore

@MainActor
final class MatchViewModel_KickoffAlternationTests: XCTestCase {

    func test_second_half_kicking_team_is_opposite() async throws {
        let vm = MatchViewModel()

        vm.setKickingTeam(true) // home kicked off first half
        XCTAssertEqual(vm.getSecondHalfKickingTeam(), .away)

        vm.setKickingTeam(false) // away kicked off first half
        XCTAssertEqual(vm.getSecondHalfKickingTeam(), .home)
    }
}
