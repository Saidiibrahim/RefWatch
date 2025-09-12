//
//  RefWatchiOSApp.swift
//  RefZoneiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import SwiftUI
import SwiftData
import RefWatchCore
import Clerk

@main
@MainActor
struct RefZoneiOSApp: App {
    @StateObject private var router = AppRouter()
    // Built once during app init to avoid lazy/self init ordering issues
    private let modelContainer: ModelContainer?
    private let historyStore: MatchHistoryStoring
    private let journalStore: JournalEntryStoring

    private let clerk = Clerk.shared
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
        let schema = Schema([CompletedMatchRecord.self, JournalEntryRecord.self])
        let auth = ClerkAuth()
        let result = ModelContainerFactory.makeStore(builder: Self.containerBuilder, schema: schema, auth: auth)
        // Build dependencies as locals first to avoid capturing `self` in escaping autoclosures
        let container = result.0
        let store = result.1
        let vm = MatchViewModel(history: store, haptics: IOSHaptics())
        let controller = ConnectivitySyncController(history: store, auth: auth)
        let jStore: JournalEntryStoring
        if let container {
            jStore = SwiftDataJournalStore(container: container, auth: auth)
        } else {
            jStore = InMemoryJournalStore()
        }

        // Assign to stored properties/wrappers
        self.modelContainer = container
        self.historyStore = store
        self.journalStore = jStore
        _matchVM = State(initialValue: vm)
        _syncController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(matchViewModel: matchVM, historyStore: historyStore)
                .environmentObject(router)
                .environmentObject(syncDiagnostics)
                .environment(\.clerk, clerk)
                .environment(\.journalStore, journalStore)
                .task {
                    if let key = Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String, !key.isEmpty {
                        clerk.configure(publishableKey: key)
                        do {
                            try await clerk.load()
                        } catch {
                            #if DEBUG
                            print("DEBUG: Clerk.load() failed: \(error)")
                            #endif
                        }
                        #if DEBUG
                        AuthStateDebugger.shared.logChange(userId: clerk.user?.id, displayName: clerk.user?.firstName ?? clerk.user?.username)
                        #endif
                    } else {
                        #if DEBUG
                        print("DEBUG: ClerkPublishableKey missing; continuing in signed-out state.")
                        #endif
                    }
                }
                #if DEBUG
                .onChange(of: clerk.user?.id) { uid in
                    AuthStateDebugger.shared.logChange(userId: uid, displayName: clerk.user?.firstName ?? clerk.user?.username)
                }
                #endif
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
