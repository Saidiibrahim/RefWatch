//
//  MainTabView.swift
//  RefZoneiOS
//
//  Minimal TabView scaffold for iOS with placeholder tabs
//

import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.workoutServices) private var workoutServices
    @Environment(\.theme) private var theme
    let matchViewModel: MatchViewModel
    let historyStore: MatchHistoryStoring
    let scheduleStore: ScheduleStoring
    let teamStore: TeamLibraryStoring

    var body: some View {
        TabView(selection: $router.selectedTab) {
            MatchesTabView(matchViewModel: matchViewModel, historyStore: historyStore, scheduleStore: scheduleStore, teamStore: teamStore)
                .tabItem { Label("Matches", systemImage: "sportscourt") }
                .tag(AppRouter.Tab.matches)

            WorkoutDashboardView(services: workoutServices)
                .tabItem { Label("Workout", systemImage: "figure.run") }
                .tag(AppRouter.Tab.workout)

            TrendsTabView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppRouter.Tab.trends)

            AssistantTabView()
                .tabItem { Label("Assistant", systemImage: "brain.head.profile") }
                .tag(AppRouter.Tab.assistant)

            SettingsTabView(historyStore: historyStore, scheduleStore: scheduleStore, teamStore: teamStore)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(theme.colors.accentSecondary)
    }
}

#if DEBUG
#Preview {
    MainTabView(
        matchViewModel: MatchViewModel(haptics: NoopHaptics()),
        historyStore: MatchHistoryService(),
        scheduleStore: ScheduleService(),
        teamStore: InMemoryTeamLibraryStore()
    )
        .environmentObject(AppRouter.preview())
        .workoutServices(.inMemoryStub())
}
#endif
