//
//  IOSMatchLifecycleHaptics.swift
//  RefWatchiOS
//
//  iOS implementation of MatchLifecycleHapticsProviding.
//

import Foundation
import RefWatchCore

struct IOSMatchLifecycleHaptics: MatchLifecycleHapticsProviding {
  private let haptics = IOSHaptics()

  func play(_ cue: MatchLifecycleHapticCue) {
    switch cue {
    case .periodBoundaryReached:
      self.haptics.play(.notify)
    case .halftimeDurationReached:
      break
    }
  }

  func cancelPendingPlayback() {}
}
