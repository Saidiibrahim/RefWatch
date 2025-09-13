import XCTest
@testable import RefZone_Watch_App

final class TimerFaceStyleDisplayNameTests: XCTestCase {
    func testDisplayNames_areUserFriendly() {
        XCTAssertEqual(TimerFaceStyle.standard.displayName, "Standard")
        XCTAssertEqual(TimerFaceStyle.proStoppage.displayName, "Pro Stoppage")
    }
}

