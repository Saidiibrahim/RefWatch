import XCTest

final class SignedOutGateUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  func testGate_whenSignedOut_showsBlockingExperience() {
    let app = XCUIApplication()
    app.launchRefWatch(authState: "signed_out")

    XCTAssertTrue(app.staticTexts["Sign in to continue"].waitForExistence(timeout: 5))
    let message = "Sign in to keep your matches, timers, and teams in sync across your devices."
    XCTAssertTrue(app.staticTexts[message].exists)
    XCTAssertTrue(app.buttons["Create Account"].exists)
  }
}
