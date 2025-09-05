//
//  RefWatchiOSApp.swift
//  RefWatchiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import SwiftUI
import RefWatchCore

@main
struct RefWatchiOSApp: App {
    @StateObject private var router = AppRouter()
    @State private var matchVM = MatchViewModel(haptics: IOSHaptics())

    var body: some Scene {
        WindowGroup {
            MainTabView(matchViewModel: matchVM)
                .environmentObject(router)
        }
    }
}
