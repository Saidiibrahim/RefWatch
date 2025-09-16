//
//  MatchControlIntents.swift
//  RefZoneWidgets
//
//  App Intents exposed to the Smart Stack widget for quick controls.
//

import AppIntents
import WidgetKit

@available(watchOS 10.0, *)
protocol MatchControlAppIntent: AppIntent {
  static var command: LiveActivityCommand { get }
  static var deepLinkAction: String { get }
}

@available(watchOS 10.0, *)
extension MatchControlAppIntent {
  static var openAppWhenRun: Bool { true }

  func perform() async throws -> some IntentResult {
    LiveActivityCommandStore().write(Self.command)
    WidgetCenter.shared.reloadTimelines(ofKind: "RefZoneWidgets")
    if let url = URL(string: "refzone://timer?action=\(Self.deepLinkAction)") {
      let openURLIntent = OpenURLIntent(url)
      return .result(opensIntent: openURLIntent)
    }
    return .result()
  }
}

// MARK: - Pause

@available(watchOS 10.0, *)
struct PauseMatchIntent: MatchControlAppIntent {
  static var title: LocalizedStringResource = "Pause Match"
  static var command: LiveActivityCommand { .pause }
  static var deepLinkAction: String { "pause" }
}

// MARK: - Resume

@available(watchOS 10.0, *)
struct ResumeMatchIntent: MatchControlAppIntent {
  static var title: LocalizedStringResource = "Resume Match"
  static var command: LiveActivityCommand { .resume }
  static var deepLinkAction: String { "resume" }
}

// MARK: - Start Half Time

@available(watchOS 10.0, *)
struct StartHalfTimeIntent: MatchControlAppIntent {
  static var title: LocalizedStringResource = "Start Half Time"
  static var command: LiveActivityCommand { .startHalfTime }
  static var deepLinkAction: String { "startHalfTime" }
}

// MARK: - Start Second Half

@available(watchOS 10.0, *)
struct StartSecondHalfIntent: MatchControlAppIntent {
  static var title: LocalizedStringResource = "Start Second Half"
  static var command: LiveActivityCommand { .startSecondHalf }
  static var deepLinkAction: String { "startSecondHalf" }
}
