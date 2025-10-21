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
    let matchSyncController: MatchHistorySyncControlling?
    let scheduleStore: ScheduleStoring
    let teamStore: TeamLibraryStoring
    let competitionStore: CompetitionLibraryStoring
    let venueStore: VenueLibraryStoring
    let authController: SupabaseAuthController
    let connectivityController: ConnectivitySyncController?

    var body: some View {
        TabView(selection: $router.selectedTab) {
            MatchesTabView(
                matchViewModel: matchViewModel,
                historyStore: historyStore,
                matchSyncController: matchSyncController,
                scheduleStore: scheduleStore,
                teamStore: teamStore,
                competitionStore: competitionStore,
                venueStore: venueStore
            )
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

            SettingsTabView(
                historyStore: historyStore,
                matchSyncController: matchSyncController,
                scheduleStore: scheduleStore,
                teamStore: teamStore,
                competitionStore: competitionStore,
                venueStore: venueStore,
                connectivityController: connectivityController,
                authController: authController
            )
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(theme.colors.accentSecondary)
    }
}

#if DEBUG
#Preview {
    let clientProvider = SupabaseClientProvider.shared
    let synchronizer = SupabaseUserProfileSynchronizer(clientProvider: clientProvider)
    MainTabView(
        matchViewModel: MatchViewModel(haptics: NoopHaptics()),
        historyStore: MatchHistoryService(),
        matchSyncController: nil,
        scheduleStore: InMemoryScheduleStore(),
        teamStore: InMemoryTeamLibraryStore(),
        competitionStore: InMemoryCompetitionLibraryStore(),
        venueStore: InMemoryVenueLibraryStore(),
        authController: SupabaseAuthController(
            clientProvider: clientProvider,
            profileSynchronizer: synchronizer
        ),
        connectivityController: nil
    )
        .environmentObject(AppRouter.preview())
        .workoutServices(.inMemoryStub())
}
#endif
