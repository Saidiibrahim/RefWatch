#if canImport(XCTest)
import XCTest

final class MatchesFlowUITests: XCTestCase {
    func test_add_upcoming_shows_in_list() throws {
        let app = XCUIApplication()
        app.launch()

        // Ensure we are on Matches
        XCTAssertTrue(app.navigationBars["Matches"].waitForExistence(timeout: 5))

        // Open add upcoming
        let addButton = app.buttons["Add Upcoming"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Fill fields
        let homeField = app.textFields["Home Team"]
        let awayField = app.textFields["Away Team"]
        XCTAssertTrue(homeField.waitForExistence(timeout: 5))
        homeField.tap(); homeField.typeText("Test Home")
        XCTAssertTrue(awayField.waitForExistence(timeout: 5))
        awayField.tap(); awayField.typeText("Test Away")

        // Save
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // Verify new row exists (in Today or Upcoming)
        let label = app.staticTexts["Test Home vs Test Away"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
    }
}

#endif

