import XCTest
@testable import RefWatchiOS

final class LiveSessionModelTests: XCTestCase {
    func testSimulateStart_whenCalled_setsActiveAndTeams() {
        let model = LiveSessionModel()
        XCTAssertFalse(model.isActive)
        model.simulateStart(home: "AAA", away: "BBB")
        XCTAssertTrue(model.isActive)
        XCTAssertEqual(model.homeTeam, "AAA")
        XCTAssertEqual(model.awayTeam, "BBB")
        // Accept either sample data (DEBUG) or minimal production defaults
        XCTAssertFalse(model.periodLabel.isEmpty)
    }

    func testEnd_whenCalled_resetsState() {
        let model = LiveSessionModel()
        model.simulateStart(home: "AAA", away: "BBB")
        model.end()
        XCTAssertFalse(model.isActive)
        XCTAssertEqual(model.score.home, 0)
        XCTAssertEqual(model.score.away, 0)
        XCTAssertEqual(model.events.count, 0)
        XCTAssertEqual(model.matchTime, "00:00")
    }
}

