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
        case .success:
            WKInterfaceDevice.current().play(.success)
        case .failure:
            WKInterfaceDevice.current().play(.failure)
        case .warning:
            WKInterfaceDevice.current().play(.retry)
        case .notification:
            WKInterfaceDevice.current().play(.notification)
        case .click:
            WKInterfaceDevice.current().play(.click)
        case .start:
            WKInterfaceDevice.current().play(.start)
        }
    }
}
