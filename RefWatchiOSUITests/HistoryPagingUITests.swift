import XCTest

final class HistoryPagingUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testInfiniteScrollLoadsMore_afterSeeding() {
    let app = XCUIApplication()
    app.launchRefWatch()

    // Ensure we have more than one page of history by seeding in DEBUG
    let settingsTab = app.tabBars.buttons["Settings"]
    if settingsTab.exists { settingsTab.tap() }
    self.seedDemoHistory(app, times: 12) // 60 items, exceeding the 50-row page size.

    self.openHistory(app)

    let table = app.collectionViews.firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 3))
    // Scroll to trigger load more
    if table.cells.firstMatch.exists {
      for _ in 0..<12 {
        table.swipeUp()
      }
    }
    // Wait briefly for async load
    sleep(1)

    XCTAssertTrue(
      app.staticTexts["Inter 1 vs Milan 1"].waitForExistence(timeout: 5),
      "Scrolling to the paging footer should load the oldest seeded page.")
  }

  func testRefreshUpdatesList_afterSeedingNewItems() {
    let app = XCUIApplication()
    app.launchRefWatch()

    // Open history first
    self.openHistory(app)
    let table = app.collectionViews.firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 3))
    // Seed new items
    app.tabBars.buttons["Settings"].tap()
    self.seedDemoHistory(app, times: 1)

    // Return and pull to refresh
    self.openHistory(app)
    let table2 = app.collectionViews.firstMatch
    XCTAssertTrue(table2.waitForExistence(timeout: 3))
    if table2.exists { table2.swipeDown() }
    sleep(1)
    XCTAssertTrue(
      app.staticTexts["Leeds United 1 vs Newcastle United 1"].waitForExistence(timeout: 5),
      "Refresh should expose history written while another tab was active.")
  }

  func testDeleteRemovesRow() {
    let app = XCUIApplication()
    app.launchRefWatch()
    app.tabBars.buttons["Settings"].tap()
    self.seedDemoHistory(app, times: 1)
    self.openHistory(app)
    let table = app.collectionViews.firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 3))
    guard table.cells.firstMatch.exists else { return }
    let firstCell = table.cells.element(boundBy: 0)
    let initialCount = table.cells.count
    if firstCell.exists {
      firstCell.swipeLeft()
      app.buttons["Delete"].firstMatch.tap()
    }
    sleep(1)
    XCTAssertLessThan(table.cells.count, initialCount)
  }

  // MARK: - Helpers

  private func seedDemoHistory(_ app: XCUIApplication, times: Int) {
    let seedButton = app.buttons["Seed Demo History"]
    guard seedButton.waitForExistence(timeout: 2) else { return }
    for _ in 0..<times {
      seedButton.tap()
    }
  }

  private func openHistory(_ app: XCUIApplication) {
    app.tabBars.buttons["Matches"].tap()
    if app.navigationBars["History"].exists == false {
      let historyButton = app.buttons["See All History"]
      if historyButton.waitForExistence(timeout: 3) {
        historyButton.tap()
      } else {
        app.buttons["History"].tap()
      }
    }
    XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
  }
}

extension XCUIElementQuery {
  fileprivate var firstMatch: XCUIElement { self.element(boundBy: 0) }
}
