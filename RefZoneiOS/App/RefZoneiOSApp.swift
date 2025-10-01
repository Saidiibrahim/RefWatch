//
//  RefZoneiOSApp.swift
//  RefZoneiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import Combine
import SwiftUI
import SwiftData
import RefWatchCore
import RefWorkoutCore
import UIKit
import OSLog

@main
@MainActor
struct RefZoneiOSApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var appModeController = AppModeController()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authController: SupabaseAuthController
    @StateObject private var authCoordinator: AuthenticationCoordinator
    // Built once during app init to avoid lazy/self init ordering issues
    private let modelContainer: ModelContainer
    private let historyStore: MatchHistoryStoring
    private let matchSyncController: MatchHistorySyncControlling?
    private let journalStore: JournalEntryStoring
    private let scheduleStore: ScheduleStoring
    private let teamStore: TeamLibraryStoring
    private let competitionStore: CompetitionLibraryStoring
    private let venueStore: VenueLibraryStoring
    private let workoutServices = IOSWorkoutServicesFactory.makeDefault()

    @State private var matchVM: MatchViewModel
    @StateObject private var syncController: ConnectivitySyncController
    @StateObject private var syncDiagnostics = SyncDiagnosticsCenter()
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastAuthState: AuthState = .signedOut

    // Exposed for tests to override container-building behavior
    static var containerBuilder: ModelContainerBuilding = DefaultModelContainerBuilder()

    init() {
        // Build SwiftData container and store with graceful fallback.
        //
        // Fallback Order (rationale):
        // 1) On-disk SwiftData (preferred): full persistence, query performance, and indexing.
        // 2) In-memory SwiftData: avoids startup crash if persistent container fails while keeping
        //    the app usable.
        // JSON persistence is no longer used now that Supabase auth is required on iPhone.
        let schema = Schema([
            CompletedMatchRecord.self,
            JournalEntryRecord.self,
            // Teams + Library
            TeamRecord.self,
            PlayerRecord.self,
            TeamOfficialRecord.self,
            // Schedule
            ScheduledMatchRecord.self,
            // Competitions
            CompetitionRecord.self,
            // Venues
            VenueRecord.self
        ])
        let clientProvider = SupabaseClientProvider.shared
        let synchronizer = SupabaseUserProfileSynchronizer(clientProvider: clientProvider)
        let authController = SupabaseAuthController(
            clientProvider: clientProvider,
            profileSynchronizer: synchronizer
        )
        _authController = StateObject(wrappedValue: authController)
        _authCoordinator = StateObject(wrappedValue: AuthenticationCoordinator(authController: authController))

        let containerResult: (ModelContainer, SwiftDataMatchHistoryStore)
        do {
            containerResult = try ModelContainerFactory.makeStore(builder: Self.containerBuilder, schema: schema, auth: authController)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }

        let container = containerResult.0
        let swiftHistoryStore = containerResult.1

        let matchRepo = SupabaseMatchHistoryRepository(
            store: swiftHistoryStore,
            authStateProvider: authController,
            deviceIdProvider: { UIDevice.current.identifierForVendor?.uuidString }
        )
        let historyRepo: MatchHistoryStoring = matchRepo
        let matchSyncController: MatchHistorySyncControlling? = matchRepo

        let vm = MatchViewModel(history: historyRepo, haptics: IOSHaptics())
        let controller = ConnectivitySyncController(history: historyRepo, auth: authController)

        let jStore: JournalEntryStoring = SwiftDataJournalStore(container: container, auth: authController)

        let swiftScheduleStore = SwiftDataScheduleStore(container: container, auth: authController)
        let schedStore: ScheduleStoring = SupabaseScheduleRepository(
            store: swiftScheduleStore,
            authStateProvider: authController
        )

        let swiftTeamStore = SwiftDataTeamLibraryStore(container: container, auth: authController)
        let tStore: TeamLibraryStoring = SupabaseTeamLibraryRepository(
            store: swiftTeamStore,
            authStateProvider: authController
        )

        let swiftCompetitionStore = SwiftDataCompetitionLibraryStore(container: container, auth: authController)
        let cStore: CompetitionLibraryStoring = SupabaseCompetitionLibraryRepository(
            store: swiftCompetitionStore,
            authStateProvider: authController
        )

        let swiftVenueStore = SwiftDataVenueLibraryStore(container: container, auth: authController)
        let vStore: VenueLibraryStoring = SupabaseVenueLibraryRepository(
            store: swiftVenueStore,
            authStateProvider: authController
        )

        // Assign to stored properties/wrappers
        self.modelContainer = container
        self.historyStore = historyRepo
        self.matchSyncController = matchSyncController
        self.journalStore = jStore
        self.scheduleStore = schedStore
        self.teamStore = tStore
        self.competitionStore = cStore
        self.venueStore = vStore
        _matchVM = State(initialValue: vm)
        _syncController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environmentObject(router)
                .environmentObject(syncDiagnostics)
                .environmentObject(appModeController)
                .environmentObject(themeManager)
                .environmentObject(authController)
                .environmentObject(authCoordinator)
                .environment(\.journalStore, journalStore)
                .workoutServices(workoutServices)
                .theme(themeManager.theme)
                .task {
                    await authController.restoreSessionIfAvailable()
                    authCoordinator.presentWelcomeIfNeeded()
                }
                .onReceive(router.$authenticationRequest.compactMap { $0 }) { screen in
                    authCoordinator.activeScreen = screen
                    router.authenticationRequest = nil
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        if authController.isSignedIn {
                            syncController.start()
                        } else {
                            syncController.stop()
                        }
                    case .inactive, .background:
                        syncController.stop()
                    @unknown default:
                        break
                    }
                }
                .onChange(of: authController.state) { state in
                    switch state {
                    case .signedIn:
                        if scenePhase == .active { syncController.start() }
                    case .signedOut:
                        syncController.stop()
                    }
                    handleAuthStateTransition(to: state)
                }
                .fullScreenCover(item: Binding(
                    get: { authCoordinator.activeScreen },
                    set: { authCoordinator.activeScreen = $0 }
                )) { screen in
                    switch screen {
                    case .welcome:
                        WelcomeView()
                            .environmentObject(authCoordinator)
                    case .signIn:
                        SignInView(authController: authController)
                            .environmentObject(authCoordinator)
                    case .signUp:
                        SignUpView(authController: authController)
                            .environmentObject(authCoordinator)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: authController.state)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch authController.state {
        case .signedIn:
            MainTabView(
                matchViewModel: matchVM,
                historyStore: historyStore,
                matchSyncController: matchSyncController,
                scheduleStore: scheduleStore,
                teamStore: teamStore,
                competitionStore: competitionStore,
                venueStore: venueStore,
                authController: authController
            )
        case .signedOut:
            SignedOutGateView()
        }
    }
}

private extension RefZoneiOSApp {
    func handleAuthStateTransition(to newState: AuthState) {
        defer { lastAuthState = newState }
        guard case .signedOut = newState else { return }
        if case .signedOut = lastAuthState { return }
        performLogoutCleanup()
    }

    func performLogoutCleanup() {
        AppLog.supabase.notice("Performing logout cleanup for local caches")
        matchVM = MatchViewModel(history: historyStore, haptics: IOSHaptics())
        if let journalStore = journalStore as? SwiftDataJournalStore {
            do {
                try journalStore.wipeAllForLogout()
            } catch {
                AppLog.supabase.error("Failed to wipe journal entries on sign-out: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
