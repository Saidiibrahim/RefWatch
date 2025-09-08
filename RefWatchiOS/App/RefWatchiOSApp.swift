//
//  RefWatchiOSApp.swift
//  RefWatchiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import SwiftUI
import SwiftData
import RefWatchCore
import Clerk

@main
struct RefWatchiOSApp: App {
    @StateObject private var router = AppRouter()
    // Built once during app init to avoid lazy/self init ordering issues
    private let modelContainer: ModelContainer?
    private let historyStore: MatchHistoryStoring

    @State private var clerk = Clerk.shared
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
        let schema = Schema([CompletedMatchRecord.self])
        let auth = ClerkAuth()
        let result = ModelContainerFactory.makeStore(builder: Self.containerBuilder, schema: schema, auth: auth)
        // Build dependencies as locals first to avoid capturing `self` in escaping autoclosures
        let container = result.0
        let store = result.1
        let vm = MatchViewModel(history: store, haptics: IOSHaptics())
        let controller = ConnectivitySyncController(history: store, auth: auth)

        // Assign to stored properties/wrappers
        self.modelContainer = container
        self.historyStore = store
        _matchVM = State(initialValue: vm)
        _syncController = StateObject(wrappedValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(matchViewModel: matchVM, historyStore: historyStore)
                .environmentObject(router)
                .environmentObject(syncDiagnostics)
                .environment(\.clerk, clerk)
                .task {
                    if let key = Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String, !key.isEmpty {
                        clerk.configure(publishableKey: key)
                        try? await clerk.load()
                    } else {
                        #if DEBUG
                        print("DEBUG: ClerkPublishableKey missing; continuing in signed-out state.")
                        #endif
                    }
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
