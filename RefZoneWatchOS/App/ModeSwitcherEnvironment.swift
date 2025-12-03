import SwiftUI
import RefWatchCore

enum ModeSwitcherBlockReason: Equatable {
  case activeMatch
  case activeWorkout

  var message: String {
    switch self {
    case .activeMatch:
      return "Finish or abandon match to switch modes"
    case .activeWorkout:
      return "Finish or abandon workout to switch modes"
    }
  }

  var activeMode: AppMode {
    switch self {
    case .activeMatch:
      return .match
    case .activeWorkout:
      return .workout
    }
  }
}

private struct ModeSwitcherPresentationKey: EnvironmentKey {
  static let defaultValue: Binding<Bool> = .constant(false)
}

private struct ModeSwitcherBlockReasonKey: EnvironmentKey {
  static let defaultValue: Binding<ModeSwitcherBlockReason?> = .constant(nil)
}

extension EnvironmentValues {
  var modeSwitcherPresentation: Binding<Bool> {
    get { self[ModeSwitcherPresentationKey.self] }
    set { self[ModeSwitcherPresentationKey.self] = newValue }
  }

  var modeSwitcherBlockReason: Binding<ModeSwitcherBlockReason?> {
    get { self[ModeSwitcherBlockReasonKey.self] }
    set { self[ModeSwitcherBlockReasonKey.self] = newValue }
  }
}
