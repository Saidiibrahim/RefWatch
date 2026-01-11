import XCTest

final class SignedOutGateUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  func testGate_whenSignedOut_showsBlockingExperience() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.staticTexts["Sign in to continue"].waitForExistence(timeout: 5))
    let message = "RefWatch on iPhone now requires a Supabase account. " +
      "Sign in to access match tools, schedules, trends, and team management."
    XCTAssertTrue(app.staticTexts[message].exists)
    XCTAssertTrue(app.buttons["Create Account"].exists)
  }
}
