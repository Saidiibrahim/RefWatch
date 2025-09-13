import XCTest
@testable import RefZone_Watch_App

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

    func testAppStorage_default_isStandard_whenKeyMissing() {
        // Given
        UserDefaults.standard.removeObject(forKey: "timer_face_style")

        // When
        let raw = UserDefaults.standard.string(forKey: "timer_face_style")
        let parsed = TimerFaceStyle.parse(raw: raw)

        // Then
        XCTAssertNil(raw)
        XCTAssertEqual(parsed, .standard)
    }

    func testAppStorage_roundTrip_persistsAndReadsBackSelection() {
        // Given
        UserDefaults.standard.removeObject(forKey: "timer_face_style")

        // When
        UserDefaults.standard.setValue(TimerFaceStyle.standard.rawValue, forKey: "timer_face_style")
        let raw = UserDefaults.standard.string(forKey: "timer_face_style")
        let parsed = TimerFaceStyle.parse(raw: raw)

        // Then
        XCTAssertEqual(raw, TimerFaceStyle.standard.rawValue)
        XCTAssertEqual(parsed, .standard)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "timer_face_style")
    }
}
