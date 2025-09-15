//
//  HapticsEnvironment.swift
//  Provides a SwiftUI Environment key for HapticsProviding so faces
//  can remain platform-agnostic and avoid direct WatchKit usage.
//

import SwiftUI
import RefWatchCore

private struct HapticsKey: EnvironmentKey {
    static let defaultValue: HapticsProviding = NoopHaptics()
}

public extension EnvironmentValues {
    var haptics: HapticsProviding {
        get { self[HapticsKey.self] }
        set { self[HapticsKey.self] = newValue }
    }
}

public extension View {
    func hapticsProvider(_ provider: HapticsProviding) -> some View {
        environment(\.haptics, provider)
    }
}

