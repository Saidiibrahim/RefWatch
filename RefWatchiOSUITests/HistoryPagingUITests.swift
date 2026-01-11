import XCTest

final class HistoryPagingUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testInfiniteScrollLoadsMore_afterSeeding() {
    let app = XCUIApplication()
    app.launch()

    // Ensure we have more than one page of history by seeding in DEBUG
    let settingsTab = app.tabBars.buttons["Settings"]
    if settingsTab.exists { settingsTab.tap() }
    self.seedDemoHistory(app, times: 3) // ~15 items

    let matchesTab = app.tabBars.buttons["Matches"]
    matchesTab.tap()
    app.buttons["History"].tap()

    let table = app.tables.firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 3))
    let initialCount = table.cells.count

    // Scroll to trigger load more
    if table.cells.firstMatch.exists {
      table.swipeUp()
      table.swipeUp()
    }
    // Wait briefly for async load
    sleep(1)

    let afterCount = table.cells.count
    XCTAssertGreaterThan(afterCount, initialCount)
  }

  func testRefreshUpdatesList_afterSeedingNewItems() {
    let app = XCUIApplication()
    app.launch()

    // Open history first
    app.tabBars.buttons["Matches"].tap()
    app.buttons["History"].tap()
    let table = app.tables.firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 3))
    let countBefore = table.cells.count

    // Seed new items
    app.tabBars.buttons["Settings"].tap()
    self.seedDemoHistory(app, times: 1)

    // Return and pull to refresh
    app.tabBars.buttons["Matches"].tap()
    app.buttons["History"].tap()
    let table2 = app.tables.firstMatch
    XCTAssertTrue(table2.waitForExistence(timeout: 3))
    if table2.exists { table2.swipeDown() }
    sleep(1)
    let countAfter = table2.cells.count
    XCTAssertGreaterThan(countAfter, countBefore)
  }

  func testDeleteRemovesRow() {
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["Matches"].tap()
    app.buttons["History"].tap()
    let table = app.tables.firstMatch
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
}

extension XCUIElementQuery {
  fileprivate var firstMatch: XCUIElement { self.element(boundBy: 0) }
}
