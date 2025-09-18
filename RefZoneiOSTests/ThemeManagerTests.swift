import XCTest
@testable import RefZoneiOS

final class ThemeManagerTests: XCTestCase {
  func test_init_usesStoredVariantWhenAvailable() {
    let suiteName = "ThemeManagerTests.init"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(ThemeVariant.highContrast.rawValue, forKey: "theme_variant")

    let manager = ThemeManager(storage: defaults)

    XCTAssertEqual(manager.variant, .highContrast)
    defaults.removePersistentDomain(forName: suiteName)
  }

  func test_apply_updatesVariantAndPersists() {
    let suiteName = "ThemeManagerTests.apply"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let manager = ThemeManager(storage: defaults)

    manager.apply(.highContrast)

    XCTAssertEqual(manager.variant, .highContrast)
    XCTAssertEqual(defaults.string(forKey: "theme_variant"), ThemeVariant.highContrast.rawValue)
    XCTAssertEqual(manager.theme.spacing.stackSpacing, 16)

    defaults.removePersistentDomain(forName: suiteName)
  }
}
