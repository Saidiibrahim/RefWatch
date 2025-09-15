//
//  WatchHaptics.swift
//  watchOS implementation of HapticsProviding
//

import Foundation
import WatchKit
import RefWatchCore

struct WatchHaptics: HapticsProviding {
    func play(_ event: HapticEvent) {
        switch event {
        // Generic results
        case .success:
            WKInterfaceDevice.current().play(.success)
        case .failure:
            WKInterfaceDevice.current().play(.failure)
        case .warning:
            WKInterfaceDevice.current().play(.retry)

        // User feedback (faces preferred)
        case .tap, .click:
            WKInterfaceDevice.current().play(.click)
        case .pause:
            WKInterfaceDevice.current().play(.stop)
        case .resume, .start:
            WKInterfaceDevice.current().play(.start)
        case .notify:
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
