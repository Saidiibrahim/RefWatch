import XCTest

final class MatchFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchRefWatch()
    }

    func testStartTimerFinish_andSeeInHistory() {
        // On Matches hub by default. Open setup
        let startCell = app.cells.staticTexts["Start Match"]
        XCTAssertTrue(startCell.waitForExistence(timeout: 3))
        startCell.tap()

        // Start immediately with defaults
        let startButton = app.buttons["Start Match"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()

        let home = app.buttons["homeTeamButton"]
        let away = app.buttons["awayTeamButton"]
        XCTAssertTrue(home.waitForExistence(timeout: 3) || away.waitForExistence(timeout: 3))
        (home.exists ? home : away).tap()
        app.buttons["Start"].tap()

        // Expect timer screen
        let timerArea = app.descendants(matching: .any)["timerArea"]
        XCTAssertTrue(timerArea.waitForExistence(timeout: 5))

        // Finish through the current actions and full-time surfaces.
        app.navigationBars.buttons["Actions"].tap()
        let finishButton = app.cells.buttons["Finish Match"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 3))
        finishButton.tap()
        let endMatchButton = app.buttons["End Match"]
        XCTAssertTrue(endMatchButton.waitForExistence(timeout: 3))
        endMatchButton.tap()
        let alert = app.alerts["End Match"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["End"].tap()

        // Back on Matches; open History and expect "Home vs Away"
        let historyButton = app.buttons["See All History"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 3))
        historyButton.tap()
        let historyRow = app.cells.staticTexts["Home vs Away"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: 5))
    }
}
