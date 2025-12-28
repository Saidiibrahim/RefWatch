import XCTest

final class ThemeSelectionUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    app = XCUIApplication()
  }

  func test_themeSelectionPersistsAcrossLaunches() {
    app.launch()
    navigateToSettings()

    let standardButton = app.buttons["Standard"]
    if standardButton.exists && !standardButton.isSelected {
      standardButton.tap()
    }

    let highContrastButton = app.buttons["High Contrast"]
    XCTAssertTrue(highContrastButton.waitForExistence(timeout: 3))
    highContrastButton.tap()
    XCTAssertTrue(highContrastButton.isSelected)

    app.terminate()

    app.launch()
    navigateToSettings()

    let highContrastAfterRelaunch = app.buttons["High Contrast"]
    XCTAssertTrue(highContrastAfterRelaunch.waitForExistence(timeout: 3))
    XCTAssertTrue(highContrastAfterRelaunch.isSelected)

    let standardAfterRelaunch = app.buttons["Standard"]
    if standardAfterRelaunch.exists && !standardAfterRelaunch.isSelected {
      standardAfterRelaunch.tap()
    }
  }

  private func navigateToSettings(file: StaticString = #filePath, line: UInt = #line) {
    let settingsTab = app.tabBars.buttons["Settings"]
    XCTAssertTrue(settingsTab.waitForExistence(timeout: 3), file: file, line: line)
    settingsTab.tap()
  }
}
