import XCTest

final class SettingsAuthUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSettings_showsSignInWhenSignedOut() {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Settings tab
        app.tabBars.buttons["Settings"].tap()

        // Expect the Sign in button to be visible when no user session exists
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 5))
    }
}

