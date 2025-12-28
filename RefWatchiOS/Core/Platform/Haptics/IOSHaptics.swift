//
//  IOSHaptics.swift
//  iOS implementation of HapticsProviding
//

import Foundation
import UIKit
import RefWatchCore

struct IOSHaptics: HapticsProviding {
    // Reuse generators to avoid unnecessary allocations; prepare to reduce latency.
    private let notificationGen = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    init() {
        // Preparing upfront helps minimize latency for the first haptic
        notificationGen.prepare()
        impact.prepare()
    }

    func play(_ event: HapticEvent) {
        switch event {
        case .success:
            notificationGen.notificationOccurred(.success)
        case .failure:
            notificationGen.notificationOccurred(.error)
        case .warning:
            notificationGen.notificationOccurred(.warning)

        case .tap, .click:
            impact.impactOccurred()
        case .pause:
            impact.impactOccurred(intensity: 0.6)
        case .resume, .start:
            impact.impactOccurred(intensity: 0.9)
        case .notify:
            notificationGen.notificationOccurred(.success)
        }
    }
}
