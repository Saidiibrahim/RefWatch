//
//  HapticsProviding.swift
//  RefWatchCore
//
//  Shared protocol to abstract platform haptics for ViewModels
//

import Foundation

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

public protocol HapticsProviding {
    func play(_ event: HapticEvent)
}

public struct NoopHaptics: HapticsProviding {
    public init() {}
    public func play(_ event: HapticEvent) { /* no-op */ }
}
