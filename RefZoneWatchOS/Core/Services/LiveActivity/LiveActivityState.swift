//
//  LiveActivityState.swift
//  RefZoneWatchOS
//
//  Versioned, minimal payload persisted in an App Group so the
//  watchOS WidgetKit extension can render the current match state
//  without duplicating any timing logic.
//

import Foundation

// MARK: - LiveActivityState v1

struct LiveActivityState: Codable, Equatable {
  // MARK: - Schema & Identity
  var version: Int = 1
  var matchIdentifier: String?

  // MARK: - Scoreboard
  var homeAbbr: String
  var awayAbbr: String
  var homeScore: Int
  var awayScore: Int

  // MARK: - Period & Status
  var periodLabel: String
  var isPaused: Bool
  var isInStoppage: Bool

  // MARK: - Timing
  /// Wall-clock start of current period (derived from VM snapshot)
  var periodStart: Date
  /// Expected wall-clock period end while running; nil when paused/finished/NA
  var expectedPeriodEnd: Date?
  /// Elapsed seconds captured at the time of pause; nil while running
  var elapsedAtPause: TimeInterval?

  // MARK: - Stoppage
  var stoppageAccumulated: TimeInterval

  // MARK: - Meta
  var lastUpdated: Date
}

extension LiveActivityState {
  static let storeKeyV1 = "liveActivity.state.v1"
}

