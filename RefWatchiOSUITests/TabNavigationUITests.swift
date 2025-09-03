import XCTest

final class TabNavigationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testSwitchTabs_whenTappingLive_showsLiveTitle() {
        // Default starts on Matches; tap Live tab
        app.tabBars.buttons["Live"].tap()
        XCTAssertTrue(app.navigationBars["Live"].waitForExistence(timeout: 2))
    }

    func testOpenFixtureDetail_andSendToWatch_showsErrorAlertWhenDisconnected() {
        // Ensure on Matches tab
        app.tabBars.buttons["Matches"].tap()

        // Tap the first fixture row (uses cell text format "Home vs Away")
        let firstCell = app.cells.containing(.staticText, identifier: " vs ").element(boundBy: 0)
        if firstCell.exists {
            firstCell.tap()
        } else {
            // Fallback: tap by static text from seed data
            app.cells.staticTexts["Leeds United vs Newcastle"].firstMatch.tap()
        }

        // Tap Send to Watch and expect an error alert in disconnected environments
        app.buttons["Send to Watch"].tap()
        XCTAssertTrue(app.alerts["Error"].waitForExistence(timeout: 2))
        app.alerts["Error"].scrollViews.otherElements.buttons["OK"].tap()
    }
}

