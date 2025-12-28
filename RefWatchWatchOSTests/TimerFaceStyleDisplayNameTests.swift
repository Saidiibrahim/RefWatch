import XCTest
@testable import RefWatch_Watch_App

final class TimerFaceStyleDisplayNameTests: XCTestCase {
    func testDisplayNames_areUserFriendly() {
        XCTAssertEqual(TimerFaceStyle.standard.displayName, "Standard")
        XCTAssertEqual(TimerFaceStyle.proStoppage.displayName, "Pro Stoppage")
    }
}

