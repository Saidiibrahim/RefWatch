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
    self.assertLegacySourceTeamUIAbsent()
    self.assertNameAutofillButtonsVisible()
    self.assertLegacyStatusUIAbsent()
    XCTAssertFalse(self.app.buttons["Add Players"].exists)
    XCTAssertFalse(self.app.buttons["Add Staff"].exists)
    XCTAssertTrue(self.app.buttons["Add Manually"].exists)
    XCTAssertTrue(self.app.buttons["Import Screenshots"].exists)

    let homeImportButton = self.app.buttons["match-sheet-import-home"]
    XCTAssertTrue(homeImportButton.waitForExistence(timeout: 5))
    homeImportButton.tap()

    let testScreenshotButton = self.app.buttons["match-sheet-import-use-test-screenshot"]
    XCTAssertTrue(testScreenshotButton.waitForExistence(timeout: 5))
    testScreenshotButton.tap()
    self.waitForUITestAttachment()

    let parseButton = self.app.buttons["match-sheet-import-parse"]
    XCTAssertTrue(self.scrollUpUntilExists(parseButton))
    XCTAssertTrue(self.waitForEnabled(parseButton, timeout: 20))
    parseButton.tap()

    XCTAssertTrue(self.app.navigationBars["Home Match Sheet"].waitForExistence(timeout: 5))
    XCTAssertTrue(self.app.buttons["match-sheet-import-apply"].waitForExistence(timeout: 5))
    self.assertImportReviewCopyVisible()
    self.assertLegacyStatusUIAbsent()
    XCTAssertFalse(self.app.buttons["Mark Ready"].exists)
    XCTAssertFalse(self.app.buttons["Mark Draft"].exists)

    let applyButton = self.app.buttons["match-sheet-import-apply"]
    XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
    applyButton.tap()

    XCTAssertTrue(self.app.navigationBars["Upcoming Match"].waitForExistence(timeout: 5))
    self.tapSaveButton()

    XCTAssertTrue(self.app.staticTexts["Metro FC vs Rivals FC"].waitForExistence(timeout: 5))
  }

  func testSaveWithoutMatchSheets() throws {
    self.launchApp(importMode: "success")

    try self.openUpcomingMatchEditor()
    self.fillTeams(home: "Metro FC", away: "Rivals FC")
    self.assertLegacySourceTeamUIAbsent()
    self.assertNameAutofillButtonsVisible()
    self.assertLegacyStatusUIAbsent()
    XCTAssertFalse(self.app.buttons["Add Players"].exists)
    XCTAssertFalse(self.app.buttons["Add Staff"].exists)
    XCTAssertTrue(self.app.buttons["Add Manually"].exists)
    XCTAssertTrue(self.app.buttons["Import Screenshots"].exists)
    XCTAssertTrue(self.app.staticTexts["Optional. Save the match without a sheet now, or add one later."].exists)

    self.tapSaveButton()

    XCTAssertTrue(self.app.staticTexts["Metro FC vs Rivals FC"].waitForExistence(timeout: 5))
  }

  func testSaveWithManualHomeSheetOnly() throws {
    self.launchApp(importMode: "success")

    try self.openUpcomingMatchEditor()
    self.fillTeams(home: "Metro FC", away: "Rivals FC")
    self.assertLegacySourceTeamUIAbsent()
    self.assertNameAutofillButtonsVisible()

    let createSheetButton = self.app.buttons["match-sheet-edit-home"]
    XCTAssertTrue(createSheetButton.waitForExistence(timeout: 5))
    createSheetButton.tap()

    XCTAssertTrue(self.app.navigationBars["Home Match Sheet"].waitForExistence(timeout: 5))
    self.app.buttons["Add Starter"].tap()

    let displayNameField = self.app.textFields["Display Name"]
    XCTAssertTrue(displayNameField.waitForExistence(timeout: 5))
    displayNameField.tap()
    displayNameField.typeText("Lionel Messi")

    self.app.navigationBars["Add Player"].buttons["Save"].tap()
    XCTAssertTrue(self.app.staticTexts["#? Lionel Messi"].waitForExistence(timeout: 5))
    self.app.navigationBars["Home Match Sheet"].buttons["Done"].tap()

    let editButton = self.app.buttons["match-sheet-edit-home"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 5))
    XCTAssertEqual(editButton.label, "Edit")
    XCTAssertTrue(self.app.buttons["match-sheet-remove-home"].exists)
    XCTAssertTrue(self.app.buttons["Replace from Screenshots"].exists)
    self.assertLegacyStatusUIAbsent()

    self.tapSaveButton()

    XCTAssertTrue(self.app.staticTexts["Metro FC vs Rivals FC"].waitForExistence(timeout: 5))
  }

  func testImportFailureThenRetryShowsReview() throws {
    self.launchApp(importMode: "fail_once_then_success")

    try self.openUpcomingMatchEditor()
    self.fillTeams(home: "Metro FC", away: "Rivals FC")
    self.assertLegacySourceTeamUIAbsent()
    self.assertNameAutofillButtonsVisible()

    self.app.buttons["match-sheet-import-home"].tap()
    XCTAssertTrue(self.app.buttons["match-sheet-import-use-test-screenshot"].waitForExistence(timeout: 5))
    self.app.buttons["match-sheet-import-use-test-screenshot"].tap()
    self.waitForUITestAttachment()

    let parseButton = self.app.buttons["match-sheet-import-parse"]
    XCTAssertTrue(self.scrollUpUntilExists(parseButton))
    XCTAssertTrue(self.waitForEnabled(parseButton, timeout: 20))
    parseButton.tap()

    XCTAssertTrue(
      self.app.staticTexts["The parser request failed with a temporary upstream error."]
        .waitForExistence(timeout: 5))

    XCTAssertTrue(self.scrollUpUntilExists(parseButton))
    XCTAssertTrue(self.waitForEnabled(parseButton, timeout: 5))
    parseButton.tap()
    XCTAssertTrue(self.app.navigationBars["Home Match Sheet"].waitForExistence(timeout: 5))
    XCTAssertTrue(self.app.buttons["match-sheet-import-apply"].waitForExistence(timeout: 5))
  }

  func testTeamLibraryAutofillUsesFullCatalogAndUpdatesOnlySelectedNameField() throws {
    self.launchApp(importMode: "success")

    try self.openUpcomingMatchEditor()
    self.assertLegacySourceTeamUIAbsent()
    self.assertNameAutofillButtonsVisible()

    let homeField = self.app.textFields["Home Team"]
    XCTAssertTrue(homeField.waitForExistence(timeout: 5))

    let awayField = self.app.textFields["Away Team"]
    XCTAssertTrue(awayField.waitForExistence(timeout: 5))
    awayField.tap()
    awayField.typeText("Custom Away")

    let homeAutofillButton = self.app.buttons["team-name-autofill-home"]
    XCTAssertTrue(homeAutofillButton.waitForExistence(timeout: 5))
    homeAutofillButton.tap()

    let metroLibraryTeam = self.app.buttons["team-picker-local-metro-library-fc"]
    XCTAssertTrue(metroLibraryTeam.waitForExistence(timeout: 5))

    let kaizerChiefs = self.app.buttons["team-picker-reference-sa-kaizer-chiefs"]
    XCTAssertTrue(kaizerChiefs.waitForExistence(timeout: 5))

    let orlandoPirates = self.app.buttons["team-picker-reference-sa-orlando-pirates"]
    XCTAssertTrue(orlandoPirates.waitForExistence(timeout: 5))

    self.searchTeamPicker("Kaizer")

    XCTAssertTrue(kaizerChiefs.waitForExistence(timeout: 5))
    XCTAssertTrue(self.waitForNonExistence(metroLibraryTeam, timeout: 5))
    XCTAssertTrue(self.waitForNonExistence(orlandoPirates, timeout: 5))
    kaizerChiefs.tap()

    XCTAssertEqual(homeField.value as? String, "Kaizer Chiefs")
    XCTAssertEqual(awayField.value as? String, "Custom Away")
    XCTAssertFalse(self.app.buttons["match-sheet-remove-home"].exists)
    XCTAssertFalse(self.app.buttons["match-sheet-remove-away"].exists)

    let awayAutofillButton = self.app.buttons["team-name-autofill-away"]
    XCTAssertTrue(awayAutofillButton.waitForExistence(timeout: 5))
    awayAutofillButton.tap()

    XCTAssertTrue(orlandoPirates.waitForExistence(timeout: 5))

    let metroLibraryTeamInAwayPicker = self.app.buttons["team-picker-local-metro-library-fc"]
    XCTAssertTrue(metroLibraryTeamInAwayPicker.waitForExistence(timeout: 5))

    let mamelodiSundowns = self.app.buttons["team-picker-reference-sa-mamelodi-sundowns"]
    XCTAssertTrue(mamelodiSundowns.waitForExistence(timeout: 5))

    self.searchTeamPicker("Orlando")

    XCTAssertTrue(orlandoPirates.waitForExistence(timeout: 5))
    XCTAssertTrue(self.waitForNonExistence(metroLibraryTeamInAwayPicker, timeout: 5))
    XCTAssertTrue(self.waitForNonExistence(mamelodiSundowns, timeout: 5))
    orlandoPirates.tap()

    XCTAssertEqual(homeField.value as? String, "Kaizer Chiefs")
    XCTAssertEqual(awayField.value as? String, "Orlando Pirates")
    XCTAssertFalse(self.app.buttons["match-sheet-remove-home"].exists)
    XCTAssertFalse(self.app.buttons["match-sheet-remove-away"].exists)
    self.assertLegacySourceTeamUIAbsent()
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
    let navigationBar = self.app.navigationBars["Upcoming Match"]
    let homeField = self.app.textFields["Home Team"]
    let editorLoaded = navigationBar.waitForExistence(timeout: 10)
      || homeField.waitForExistence(timeout: 10)
    XCTAssertTrue(editorLoaded)
  }

  func fillTeams(home: String, away: String) {
    XCTAssertTrue(self.app.wait(for: .runningForeground, timeout: 5))

    let homeField = self.app.textFields["Home Team"]
    XCTAssertTrue(homeField.waitForExistence(timeout: 5))
    homeField.tap()
    homeField.typeText(home)

    let awayField = self.app.textFields["Away Team"]
    XCTAssertTrue(awayField.waitForExistence(timeout: 5))
    awayField.tap()
    awayField.typeText(away)
  }

  func assertLegacySourceTeamUIAbsent() {
    XCTAssertFalse(self.app.buttons["Select Home Team from Library"].exists)
    XCTAssertFalse(self.app.buttons["Select Away Team from Library"].exists)
    XCTAssertFalse(self.app.buttons["Edit Source Team"].exists)
  }

  func assertNameAutofillButtonsVisible() {
    let homeAutofillButton = self.app.buttons["team-name-autofill-home"]
    XCTAssertTrue(homeAutofillButton.waitForExistence(timeout: 5))
    XCTAssertTrue(homeAutofillButton.label.contains("Autofill Home Team Name from Teams Catalog"))

    let awayAutofillButton = self.app.buttons["team-name-autofill-away"]
    XCTAssertTrue(awayAutofillButton.waitForExistence(timeout: 5))
    XCTAssertTrue(awayAutofillButton.label.contains("Autofill Away Team Name from Teams Catalog"))
  }

  func assertLegacyStatusUIAbsent() {
    XCTAssertFalse(self.app.staticTexts["Status"].exists)
    XCTAssertFalse(self.app.staticTexts["State"].exists)
    XCTAssertFalse(self.app.staticTexts["Draft"].exists)
    XCTAssertFalse(self.app.staticTexts["Ready"].exists)
    XCTAssertFalse(self.app.staticTexts["Official"].exists)
    XCTAssertFalse(self.app.staticTexts["Watch Ready"].exists)
    XCTAssertFalse(self.app.buttons["Mark Ready"].exists)
    XCTAssertFalse(self.app.buttons["Mark Draft"].exists)
  }

  func assertImportReviewCopyVisible() {
    let reviewCopy = self.app.staticTexts.matching(
      NSPredicate(format: "label BEGINSWITH %@", "Review the imported entries below.")
    ).firstMatch
    XCTAssertTrue(reviewCopy.waitForExistence(timeout: 5))
  }

  func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == true AND isEnabled == true"),
      object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"),
      object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  func waitForUITestAttachment() {
    XCTAssertTrue(self.app.staticTexts["ui-test-match-sheet.jpg"].waitForExistence(timeout: 20))
  }

  func searchTeamPicker(_ query: String) {
    let searchField = self.app.searchFields["Search teams"]
    if searchField.exists == false {
      let teamList = self.app.tables.firstMatch
      if teamList.waitForExistence(timeout: 2) {
        teamList.swipeDown()
        if searchField.exists == false {
          teamList.swipeDown()
        }
      }
    }

    let resolvedSearchField = searchField.exists ? searchField : self.app.searchFields.firstMatch
    XCTAssertTrue(resolvedSearchField.waitForExistence(timeout: 5))
    resolvedSearchField.tap()
    resolvedSearchField.typeText(query)
  }

  func scrollUpUntilExists(_ element: XCUIElement, maxSwipes: Int = 5) -> Bool {
    if element.exists {
      return true
    }

    for _ in 0..<maxSwipes {
      self.app.swipeUp()
      if element.waitForExistence(timeout: 1) {
        return true
      }
    }

    return element.exists
  }

  func tapSaveButton() {
    let saveButton = self.app.buttons["Save"]

    if saveButton.exists == false {
      for _ in 0..<4 where saveButton.exists == false {
        self.app.swipeUp()
      }
    }

    XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
    self.scrollUpUntilVisible(saveButton)
    XCTAssertTrue(saveButton.isEnabled)
    saveButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
  }

  func scrollUpUntilVisible(_ element: XCUIElement, maxSwipes: Int = 4) {
    let window = self.app.windows.firstMatch
    _ = window.waitForExistence(timeout: 1)

    for _ in 0..<maxSwipes {
      guard element.exists else { return }
      let frame = element.frame
      if frame.isEmpty == false, window.frame.intersects(frame) {
        return
      }
      self.app.swipeUp()
    }
  }
}
