//
//  MatchLifecycleHapticsProviding.swift
//  RefWatchCore
//
//  Semantic haptics protocol for match lifecycle cues shared across platforms.
//

import Foundation

/// Semantic lifecycle cues emitted by shared match flow logic.
public enum MatchLifecycleHapticCue: Equatable, Sendable {
  case periodBoundaryReached
  case halftimeDurationReached
}

/// Provides platform-specific playback for match lifecycle haptic cues.
public protocol MatchLifecycleHapticsProviding {
  /// Triggers the haptic sequence for a lifecycle cue.
  func play(_ cue: MatchLifecycleHapticCue)

  /// Cancels any queued lifecycle haptic playback that should not outlive the
  /// state that triggered it.
  func cancelPendingPlayback()
}

public struct NoopMatchLifecycleHaptics: MatchLifecycleHapticsProviding {
  public init() {}

  public func play(_ cue: MatchLifecycleHapticCue) {}

  public func cancelPendingPlayback() {}
}
