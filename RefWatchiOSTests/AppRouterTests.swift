import XCTest
@testable import RefWatchiOS

final class AppRouterTests: XCTestCase {
    func testDefaultTab_whenInitialized_isMatches() {
        let router = AppRouter()
        XCTAssertEqual(router.selectedTab, .matches)
    }

    func testSelectingLive_whenSettingSelectedTab_doesUpdate() {
        let router = AppRouter()
        router.selectedTab = .live
        XCTAssertEqual(router.selectedTab, .live)
    }
}

