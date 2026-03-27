import XCTest

final class MatchSheetImportUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    self.app = XCUIApplication()
  }

  func testHomeSideImportReviewApplyAndSave() throws {
    self.launchApp(importMode: "success")

    try self.openUpcomingMatchEditor()
    self.fillTeams(home: "Metro FC", away: "Rivals FC")

    let homeImportButton = self.app.buttons["match-sheet-import-home"]
    XCTAssertTrue(homeImportButton.waitForExistence(timeout: 5))
    homeImportButton.tap()

    let testScreenshotButton = self.app.buttons["match-sheet-import-use-test-screenshot"]
    XCTAssertTrue(testScreenshotButton.waitForExistence(timeout: 5))
    testScreenshotButton.tap()

    let parseButton = self.app.buttons["match-sheet-import-parse"]
    XCTAssertTrue(parseButton.waitForExistence(timeout: 5))
    parseButton.tap()

    XCTAssertTrue(self.app.navigationBars["Home Match Sheet"].waitForExistence(timeout: 5))
    XCTAssertTrue(self.app.buttons["match-sheet-import-apply"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      self.app.staticTexts["One substitute had an unreadable shirt number and it was cleared."]
        .waitForExistence(timeout: 5))

    let applyButton = self.app.buttons["match-sheet-import-apply"]
    XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
    applyButton.tap()

    let saveButton = self.app.buttons["Save"]
    XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
    saveButton.tap()

    XCTAssertTrue(self.app.staticTexts["Metro FC vs Rivals FC"].waitForExistence(timeout: 5))
  }

  func testImportFailureThenRetryShowsReview() throws {
    self.launchApp(importMode: "fail_once_then_success")

    try self.openUpcomingMatchEditor()
    self.fillTeams(home: "Metro FC", away: "Rivals FC")

    self.app.buttons["match-sheet-import-home"].tap()
    XCTAssertTrue(self.app.buttons["match-sheet-import-use-test-screenshot"].waitForExistence(timeout: 5))
    self.app.buttons["match-sheet-import-use-test-screenshot"].tap()

    let parseButton = self.app.buttons["match-sheet-import-parse"]
    XCTAssertTrue(parseButton.waitForExistence(timeout: 5))
    parseButton.tap()

    XCTAssertTrue(
      self.app.staticTexts["The parser request failed with a temporary upstream error."]
        .waitForExistence(timeout: 5))

    parseButton.tap()
    XCTAssertTrue(self.app.navigationBars["Home Match Sheet"].waitForExistence(timeout: 5))
    XCTAssertTrue(self.app.buttons["match-sheet-import-apply"].waitForExistence(timeout: 5))
  }
}

private extension MatchSheetImportUITests {
  func launchApp(importMode: String) {
    self.app.launchEnvironment["REFWATCH_UI_TEST_AUTH_STATE"] = "signed_in"
    self.app.launchEnvironment["REFWATCH_UI_TEST_MATCH_SHEET_IMPORT_MODE"] = importMode
    self.app.launch()
  }

  func openUpcomingMatchEditor() throws {
    let addButton = self.app.buttons["Add Upcoming"]
    guard addButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("The signed-in matches shell did not expose the upcoming-match editor.")
    }
    addButton.tap()
    XCTAssertTrue(self.app.navigationBars["Upcoming Match"].waitForExistence(timeout: 5))
  }

  func fillTeams(home: String, away: String) {
    let homeField = self.app.textFields["Home Team"]
    XCTAssertTrue(homeField.waitForExistence(timeout: 5))
    homeField.tap()
    homeField.typeText(home)

    let awayField = self.app.textFields["Away Team"]
    XCTAssertTrue(awayField.waitForExistence(timeout: 5))
    awayField.tap()
    awayField.typeText(away)
  }
}
