//
//  RefWatchiOSApp.swift
//  RefWatchiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import SwiftUI

@main
struct RefWatchiOSApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var liveSession = LiveSessionModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(router)
                .environmentObject(liveSession)
        }
    }
}
