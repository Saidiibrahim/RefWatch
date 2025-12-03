import XCTest
@testable import RefWatchCore

final class AppModeControllerTests: XCTestCase {
  private let suiteName = "AppModeControllerTests"

  override func tearDown() {
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    super.tearDown()
  }

  func test_initialDefaults_areMatchAndNotPersisted() {
    let defaults = UserDefaults(suiteName: suiteName)!
    let controller = AppModeController(defaults: defaults)

    XCTAssertEqual(controller.currentMode, .match)
    XCTAssertFalse(controller.hasPersistedSelection)
    XCTAssertNil(defaults.string(forKey: "selected_app_mode"))
  }

  func test_select_persistsAndMarksHasPersistedSelection() {
    let defaults = UserDefaults(suiteName: suiteName)!
    let controller = AppModeController(defaults: defaults)

    controller.select(.workout)

    XCTAssertEqual(controller.currentMode, .workout)
    XCTAssertTrue(controller.hasPersistedSelection)
    XCTAssertEqual(defaults.string(forKey: "selected_app_mode"), AppMode.workout.rawValue)
  }

  func test_select_sameModeCanPersistFirstRun() {
    let defaults = UserDefaults(suiteName: suiteName)!
    let controller = AppModeController(defaults: defaults)

    controller.select(.match, persist: true)

    XCTAssertTrue(controller.hasPersistedSelection)
    XCTAssertEqual(defaults.string(forKey: "selected_app_mode"), AppMode.match.rawValue)
  }

  func test_select_withoutPersist_doesNotTouchDefaults() {
    let defaults = UserDefaults(suiteName: suiteName)!
    let controller = AppModeController(defaults: defaults)

    controller.select(.workout, persist: false)

    XCTAssertEqual(controller.currentMode, .workout)
    XCTAssertFalse(controller.hasPersistedSelection)
    XCTAssertNil(defaults.string(forKey: "selected_app_mode"))
  }

  func test_overrideForActiveSession_updatesCurrentButNotPersistence() {
    let defaults = UserDefaults(suiteName: suiteName)!
    let controller = AppModeController(defaults: defaults)

    controller.overrideForActiveSession(.workout)

    XCTAssertEqual(controller.currentMode, .workout)
    XCTAssertFalse(controller.hasPersistedSelection)
    XCTAssertNil(defaults.string(forKey: "selected_app_mode"))
  }
}
