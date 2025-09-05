import XCTest

final class MatchFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
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

        // Expect timer screen
        let timerArea = app.otherElements["timerArea"]
        XCTAssertTrue(timerArea.waitForExistence(timeout: 5))

        // Finish
        app.navigationBars.buttons["Finish"].tap()
        let alert = app.alerts["Finish Match?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Finish"].tap()

        // Back on Matches; open History and expect "Home vs Away"
        let historyButton = app.navigationBars.buttons["History"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 3))
        historyButton.tap()
        let historyRow = app.cells.staticTexts["Home vs Away"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: 5))
    }
}
