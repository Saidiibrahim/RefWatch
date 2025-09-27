//
//  RefZoneiOSApp.swift
//  RefZoneiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import SwiftUI
import SwiftData
import RefWatchCore
import RefWorkoutCore
import UIKit

@main
@MainActor
struct RefZoneiOSApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var appModeController = AppModeController()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authController: SupabaseAuthController
    // Built once during app init to avoid lazy/self init ordering issues
    private let modelContainer: ModelContainer?
    private let historyStore: MatchHistoryStoring
    private let matchSyncController: MatchHistorySyncControlling?
    private let journalStore: JournalEntryStoring
    private let scheduleStore: ScheduleStoring
    private let teamStore: TeamLibraryStoring
    private let workoutServices = IOSWorkoutServicesFactory.makeDefault()

    @State private var matchVM: MatchViewModel
    @StateObject private var syncController: ConnectivitySyncController
    @StateObject private var syncDiagnostics = SyncDiagnosticsCenter()
    @Environment(\.scenePhase) private var scenePhase

    // Exposed for tests to override container-building behavior
    static var containerBuilder: ModelContainerBuilding = DefaultModelContainerBuilder()

    init() {
        // Build SwiftData container and store with graceful fallback.
        //
        // Fallback Order (rationale):
        // 1) On-disk SwiftData (preferred): full persistence, query performance, and indexing.
        // 2) In-memory SwiftData: avoids startup crash if persistent container fails; keeps app usable.
        // 3) JSON store: final safety net to ensure critical features continue to work.
        let schema = Schema([
            CompletedMatchRecord.self,
            JournalEntryRecord.self,
            // Teams + Library
            TeamRecord.self,
            PlayerRecord.self,
            TeamOfficialRecord.self,
            // Schedule
            ScheduledMatchRecord.self
        ])
        let authController = SupabaseAuthController(clientProvider: SupabaseClientProvider.shared)
        _authController = StateObject(wrappedValue: authController)

        let result = ModelContainerFactory.makeStore(builder: Self.containerBuilder, schema: schema, auth: authController)
        // Build dependencies as locals first to avoid capturing `self` in escaping autoclosures
        let container = result.0
        let rawStore = result.1

        let historyRepo: MatchHistoryStoring
        let matchSyncController: MatchHistorySyncControlling?

        if let swiftStore = rawStore as? SwiftDataMatchHistoryStore {
            do {
                let repo = SupabaseMatchHistoryRepository(
                    store: swiftStore,
                    authStateProvider: authController,
                    deviceIdProvider: { UIDevice.current.identifierForVendor?.uuidString }
                )
                historyRepo = repo
                matchSyncController = repo
            } catch {
                #if DEBUG
                print("DEBUG: SupabaseMatchHistoryRepository creation failed, falling back to local store: \(error)")
                #endif
                // Fallback to local-only store if Supabase integration fails
                historyRepo = swiftStore
                matchSyncController = nil
            }
        } else {
            historyRepo = rawStore
            matchSyncController = nil
        }

        let vm = MatchViewModel(history: historyRepo, haptics: IOSHaptics())
        let controller = ConnectivitySyncController(history: historyRepo, auth: authController)
        let jStore: JournalEntryStoring
        let schedStore: ScheduleStoring
        let tStore: TeamLibraryStoring
        if let container {
            jStore = SwiftDataJournalStore(container: container, auth: authController)

            let swiftScheduleStore = SwiftDataScheduleStore(container: container, importJSONOnFirstRun: true)
            do {
                schedStore = SupabaseScheduleRepository(
                    store: swiftScheduleStore,
                    authStateProvider: authController
                )
            } catch {
                #if DEBUG
                print("DEBUG: SupabaseScheduleRepository creation failed, falling back to local store: \(error)")
                #endif
                // Fallback to local-only schedule store
                schedStore = swiftScheduleStore
            }

            let swiftTeamStore = SwiftDataTeamLibraryStore(container: container)
            do {
                tStore = SupabaseTeamLibraryRepository(
                    store: swiftTeamStore,
                    authStateProvider: authController
                )
            } catch {
                #if DEBUG
                print("DEBUG: SupabaseTeamLibraryRepository creation failed, falling back to local store: \(error)")
                #endif
                // Fallback to local-only team store
                tStore = swiftTeamStore
            }
        } else {
            jStore = InMemoryJournalStore()
            schedStore = ScheduleService()
            tStore = InMemoryTeamLibraryStore()
        }

        // Assign to stored properties/wrappers
        self.modelContainer = container
        self.historyStore = historyRepo
        self.matchSyncController = matchSyncController
        self.journalStore = jStore
        self.scheduleStore = schedStore
        self.teamStore = tStore
        _matchVM = State(initialValue: vm)
        _syncController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                matchViewModel: matchVM,
                historyStore: historyStore,
                matchSyncController: matchSyncController,
                scheduleStore: scheduleStore,
                teamStore: teamStore,
                authController: authController
            )
                .environmentObject(router)
                .environmentObject(syncDiagnostics)
                .environmentObject(appModeController)
                .environmentObject(themeManager)
                .environmentObject(authController)
                .environment(\.journalStore, journalStore)
                .workoutServices(workoutServices)
                .theme(themeManager.theme)
                .task {
                    await authController.restoreSessionIfAvailable()
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        syncController.start()
                    case .inactive, .background:
                        syncController.stop()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
