import XCTest
@testable import RefWatch_Watch_App

@MainActor
final class TimerFaceStyleParsingTests: XCTestCase {
    func testParse_returnsStandard_forNil() {
        XCTAssertEqual(TimerFaceStyle.parse(raw: nil), .standard)
    }

    func testParse_returnsStandard_forUnknownRaw() {
        XCTAssertEqual(TimerFaceStyle.parse(raw: "unknown_face"), .standard)
    }

    func testParse_returnsExactMatch_forKnownRaw() {
        XCTAssertEqual(TimerFaceStyle.parse(raw: TimerFaceStyle.standard.rawValue), .standard)
    }
}

