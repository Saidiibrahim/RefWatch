//
//  MatchLiveActivityPublishing.swift
//  RefWatchWatchOS
//
//  Narrow publisher interface used by watch match previews to suppress
//  Live Activity side effects without changing flow logic.
//

import RefWatchCore

@MainActor
protocol MatchLiveActivityPublishing: AnyObject {
  func publish(for model: MatchViewModel)
  func end()
}
