@testable import RefWatchCore
import XCTest

final class AppModeControllerTests: XCTestCase {
  func testHasPersistedSelectionReflectsDefaults() {
    let suiteName = "AppModeControllerTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create defaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let controller = AppModeController(defaults: defaults, storageKey: "mode_pref")
    XCTAssertFalse(controller.hasPersistedSelection)
    XCTAssertEqual(controller.currentMode, .match)

    controller.select(.match)

    XCTAssertTrue(controller.hasPersistedSelection)
    XCTAssertEqual(controller.currentMode, .match)

    let restored = AppModeController(defaults: defaults, storageKey: "mode_pref")
    XCTAssertTrue(restored.hasPersistedSelection)
    XCTAssertEqual(restored.currentMode, .match)
  }

  func testResetClearsSelection() {
    let suiteName = "AppModeControllerTests.Reset.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create defaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let controller = AppModeController(defaults: defaults, storageKey: "mode_pref")
    controller.select(.match)
    controller.reset()

    XCTAssertFalse(controller.hasPersistedSelection)
    XCTAssertEqual(controller.currentMode, .match)
    XCTAssertNil(defaults.string(forKey: "mode_pref"))
  }

  func testLegacyStoredModeFallsBackToMatch() {
    let suiteName = "AppModeControllerTests.Legacy.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create defaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("workout", forKey: "mode_pref")

    let controller = AppModeController(defaults: defaults, storageKey: "mode_pref")
    XCTAssertFalse(controller.hasPersistedSelection)
    XCTAssertEqual(controller.currentMode, .match)
    XCTAssertEqual(defaults.string(forKey: "mode_pref"), "match")
  }
}
