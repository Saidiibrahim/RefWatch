//
//  HapticsProviding.swift
//  Shared protocol to abstract platform haptics for VMs
//

import Foundation

enum HapticEvent {
    case success
    case failure
    case warning
    case notification
    case click
    case start
}

protocol HapticsProviding {
    func play(_ event: HapticEvent)
}

struct NoopHaptics: HapticsProviding {
    func play(_ event: HapticEvent) { /* no-op */ }
}
