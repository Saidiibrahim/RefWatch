//
//  MainTabView.swift
//  RefWatchiOS
//
//  Minimal TabView scaffold for iOS with placeholder tabs
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var liveSession: LiveSessionModel

    var body: some View {
        TabView(selection: $router.selectedTab) {
            MatchesTabView()
                .tabItem { Label("Matches", systemImage: "sportscourt") }
                .tag(AppRouter.Tab.matches)

            LiveTabView()
                .tabItem { Label("Live", systemImage: "timer") }
                .tag(AppRouter.Tab.live)

            TrendsTabView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppRouter.Tab.trends)

            LibraryTabView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppRouter.Tab.library)

            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(AppTheme.primaryAccent)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppRouter.preview())
        .environmentObject(LiveSessionModel.preview())
}
