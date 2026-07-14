#if canImport(XCTest)
import XCTest

final class LibraryFlowUITests: XCTestCase {
    func test_open_library_tab_and_teams() throws {
        let app = XCUIApplication()
        app.launchRefWatch()
        let settingsButton = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        let libraryButton = app.buttons["View Library"]
        XCTAssertTrue(libraryButton.waitForExistence(timeout: 5))
        libraryButton.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Teams"].waitForExistence(timeout: 5))
    }
}

#endif
