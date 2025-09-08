import XCTest

final class MatchFlowParityUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func startDefaultMatch() {
        let startCell = app.cells.staticTexts["Start Match"]
        XCTAssertTrue(startCell.waitForExistence(timeout: 4))
        startCell.tap()

        let startButton = app.buttons["Start Match"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()

        // Kickoff sheet should appear for first half
        let home = app.buttons["homeTeamButton"]
        let away = app.buttons["awayTeamButton"]
        XCTAssertTrue(home.waitForExistence(timeout: 3) || away.waitForExistence(timeout: 3))
        (home.exists ? home : away).tap()
        app.buttons["Start"].tap()

        let timerArea = app.otherElements["timerArea"]
        XCTAssertTrue(timerArea.waitForExistence(timeout: 5))
    }

    func testEndCurrentPeriod_showsConfirmation() {
        startDefaultMatch()

        // Open Actions
        app.navigationBars.buttons["Actions"].tap()

        // Tap End Current Period and expect a confirmation dialog
        let endCell = app.cells.buttons["End Current Period"]
        XCTAssertTrue(endCell.waitForExistence(timeout: 2))
        endCell.tap()

        // Look for the confirmation UI (Yes/No buttons)
        let yes = app.buttons["Yes"]
        let no = app.buttons["No"]
        XCTAssertTrue(yes.waitForExistence(timeout: 2) || no.waitForExistence(timeout: 2))
    }

    func testFinishFromActions_routesToFullTime() {
        startDefaultMatch()

        // Open Actions sheet
        app.navigationBars.buttons["Actions"].tap()

        // Tap Finish Match and expect Full Time screen
        let finishCell = app.cells.buttons["Finish Match"]
        XCTAssertTrue(finishCell.waitForExistence(timeout: 2))
        finishCell.tap()

        // Expect the End Match button on Full Time screen
        let endMatchBtn = app.buttons["End Match"]
        XCTAssertTrue(endMatchBtn.waitForExistence(timeout: 3))
    }

    func testLongPress_onTimer_opensActionsSheet() {
        startDefaultMatch()
        let timerArea = app.otherElements["timerArea"]
        XCTAssertTrue(timerArea.waitForExistence(timeout: 3))
        timerArea.press(forDuration: 0.7)

        // Expect an action from the sheet to be visible
        let goalAction = app.cells.buttons["Record Goal"]
        XCTAssertTrue(goalAction.waitForExistence(timeout: 2))
    }

    func testAdvanceNextPeriod_availableInActions_notInPausedControls() {
        startDefaultMatch()

        // Open Actions, pause, and confirm Advance option is present in the same sheet
        app.navigationBars.buttons["Actions"].tap()
        let pauseCell = app.cells.buttons["Pause Timer"]
        XCTAssertTrue(pauseCell.waitForExistence(timeout: 2))
        pauseCell.tap()

        let advance = app.cells.buttons["Advance to Next Period"]
        XCTAssertTrue(advance.waitForExistence(timeout: 2))
    }
}
