//
//  MainTabView.swift
//  RefWatchiOS
//
//  Minimal TabView scaffold for iOS with placeholder tabs
//

import SwiftUI
import RefWatchCore

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    let matchViewModel: MatchViewModel
    let historyStore: MatchHistoryStoring

    var body: some View {
        TabView(selection: $router.selectedTab) {
            MatchesTabView(matchViewModel: matchViewModel)
                .tabItem { Label("Matches", systemImage: "sportscourt") }
                .tag(AppRouter.Tab.matches)

            TrendsTabView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppRouter.Tab.trends)

            LibraryTabView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppRouter.Tab.library)

            SettingsTabView(historyStore: historyStore)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(AppTheme.primaryAccent)
    }
}

#Preview {
    MainTabView(matchViewModel: MatchViewModel(haptics: NoopHaptics()), historyStore: MatchHistoryService())
        .environmentObject(AppRouter.preview())
}
