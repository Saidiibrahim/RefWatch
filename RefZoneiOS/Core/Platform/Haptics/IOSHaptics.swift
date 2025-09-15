//
//  IOSHaptics.swift
//  iOS implementation of HapticsProviding
//

import Foundation
import UIKit
import RefWatchCore

struct IOSHaptics: HapticsProviding {
    private let successGen = UINotificationFeedbackGenerator()
    private let warningGen = UINotificationFeedbackGenerator()
    private let errorGen = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    func play(_ event: HapticEvent) {
        switch event {
        case .success:
            successGen.notificationOccurred(.success)
        case .failure:
            errorGen.notificationOccurred(.error)
        case .warning:
            warningGen.notificationOccurred(.warning)

        case .tap, .click:
            impact.impactOccurred()
        case .pause:
            impact.impactOccurred(intensity: 0.6)
        case .resume, .start:
            impact.impactOccurred(intensity: 0.9)
        case .notify:
            successGen.notificationOccurred(.success)
        }
    }
}
