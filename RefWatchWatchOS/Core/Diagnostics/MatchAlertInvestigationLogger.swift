//
//  MatchAlertInvestigationLogger.swift
//  RefWatchWatchOS
//
//  Description: Temporary structured logging for the repeating lifecycle-alert
//  investigation on physical watch hardware.
//

#if os(watchOS)
import Foundation
import OSLog
import RefWatchCore

enum MatchAlertInvestigationLogger {
  private static let logger = Logger(subsystem: "RefWatchWatchOS", category: "matchAlertInvestigation")

  static func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }

  static func timestamped(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    logger.debug("[\(timestamp, privacy: .public)] \(message, privacy: .public)")
  }
}

extension MatchLifecycleHapticCue {
  var debugName: String {
    switch self {
    case let .periodBoundaryReached(boundaryDecision):
      "periodBoundaryReached.\(boundaryDecision.rawValue)"
    case .halftimeDurationReached:
      "halftimeDurationReached"
    }
  }
}
#endif
