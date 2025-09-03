//
//  MainTabView.swift
//  RefWatchiOS
//
//  Minimal TabView scaffold for iOS with placeholder tabs
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var liveSession = LiveSessionModel()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            MatchesTabView()
                .environmentObject(router)
                .environmentObject(liveSession)
                .tabItem { Label("Matches", systemImage: "sportscourt") }
                .tag(0)

            LiveTabView()
                .environmentObject(router)
                .environmentObject(liveSession)
                .tabItem { Label("Live", systemImage: "timer") }
                .tag(1)

            TrendsTabView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)

            LibraryTabView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(3)

            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
        .tint(AppTheme.primaryAccent)
    }
}

#Preview {
    MainTabView()
}

