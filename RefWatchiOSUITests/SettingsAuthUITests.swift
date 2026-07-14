import XCTest

final class SettingsAuthUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSignedOutShell_showsSignInAction() {
        let app = XCUIApplication()
        app.launchRefWatch(authState: "signed_out")

        // Signed-out users are blocked at the authentication gate.
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 5))
    }
}
