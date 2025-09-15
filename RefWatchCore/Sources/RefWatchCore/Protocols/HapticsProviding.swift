//
//  HapticsProviding.swift
//  RefWatchCore
//
//  Shared protocol to abstract platform haptics for ViewModels
//

import Foundation

/// Semantic haptic events used across platforms. Implementations map these
/// to the closest native feedback for the target platform.
public enum HapticEvent {
    // Generic results
    case success
    case failure
    case warning

    // User feedback
    case tap       // lightweight, used for simple taps
    case pause     // pausing an action/timer
    case resume    // resuming/starting an action/timer
    case notify    // prominent notification cue
    
    // Legacy mappings kept for compatibility in adapters (no direct use in faces)
    case click
    case start
}

/// Provides platform-agnostic haptic feedback
public protocol HapticsProviding {
    /// Triggers haptic feedback for the specified event
    func play(_ event: HapticEvent)
}

public struct NoopHaptics: HapticsProviding {
    public init() {}
    public func play(_ event: HapticEvent) { /* no-op */ }
}
