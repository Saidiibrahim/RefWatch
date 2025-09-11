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
        case .notification:
            successGen.notificationOccurred(.success)
        case .click:
            impact.impactOccurred()
        case .start:
            impact.impactOccurred(intensity: 0.9)
        }
    }
}
