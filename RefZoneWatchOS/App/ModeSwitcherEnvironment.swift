import SwiftUI

private struct ModeSwitcherPresentationKey: EnvironmentKey {
  static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
  var modeSwitcherPresentation: Binding<Bool> {
    get { self[ModeSwitcherPresentationKey.self] }
    set { self[ModeSwitcherPresentationKey.self] = newValue }
  }
}
