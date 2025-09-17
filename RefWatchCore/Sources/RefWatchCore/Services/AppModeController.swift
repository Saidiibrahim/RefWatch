import Combine
import Foundation

@MainActor
public final class AppModeController: ObservableObject {
  @Published public private(set) var currentMode: AppMode

  private let defaults: UserDefaults
  private let storageKey: String

  public init(defaults: UserDefaults = .standard, storageKey: String = "selected_app_mode") {
    self.defaults = defaults
    self.storageKey = storageKey

    if let stored = defaults.string(forKey: storageKey),
       let mode = AppMode(rawValue: stored) {
      currentMode = mode
    } else {
      currentMode = .match
    }
  }

  public func select(_ mode: AppMode, persist: Bool = true) {
    guard currentMode != mode else {
      if persist { defaults.set(mode.rawValue, forKey: storageKey) }
      return
    }
    currentMode = mode
    if persist {
      defaults.set(mode.rawValue, forKey: storageKey)
    }
  }

  @discardableResult
  public func toggle() -> AppMode {
    let next: AppMode = currentMode == .match ? .workout : .match
    select(next)
    return next
  }

  public func overrideForActiveSession(_ mode: AppMode) {
    guard currentMode != mode else { return }
    currentMode = mode
  }

  public func reset() {
    defaults.removeObject(forKey: storageKey)
    currentMode = .match
  }
}
