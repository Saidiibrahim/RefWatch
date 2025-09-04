//
//  HapticsProviding.swift
//  RefWatchCore
//
//  Shared protocol to abstract platform haptics for ViewModels
//

import Foundation

public enum HapticEvent {
    case success
    case failure
    case warning
    case notification
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

