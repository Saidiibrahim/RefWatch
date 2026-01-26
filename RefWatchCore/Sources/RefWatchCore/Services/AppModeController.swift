import Combine
import Foundation

@MainActor
public final class AppModeController: ObservableObject {
  @Published public private(set) var currentMode: AppMode
  @Published public private(set) var hasPersistedSelection: Bool

  private let defaults: UserDefaults
  private let storageKey: String

  public init(defaults: UserDefaults = .standard, storageKey: String = "selected_app_mode") {
    self.defaults = defaults
    self.storageKey = storageKey

    if let stored = defaults.string(forKey: storageKey),
       let mode = AppMode(rawValue: stored) {
      currentMode = mode
      hasPersistedSelection = true
    } else {
      currentMode = .match
      hasPersistedSelection = false
      if defaults.string(forKey: storageKey) != nil {
        defaults.set(AppMode.match.rawValue, forKey: storageKey)
      }
    }
  }

  public func select(_ mode: AppMode, persist: Bool = true) {
    guard currentMode != mode else {
      if persist {
        defaults.set(mode.rawValue, forKey: storageKey)
        hasPersistedSelection = true
      }
      return
    }
    currentMode = mode
    if persist {
      defaults.set(mode.rawValue, forKey: storageKey)
      hasPersistedSelection = true
    }
  }

  public func overrideForActiveSession(_ mode: AppMode) {
    guard currentMode != mode else { return }
    currentMode = mode
  }

  public func reset() {
    defaults.removeObject(forKey: storageKey)
    currentMode = .match
    hasPersistedSelection = false
  }
}
