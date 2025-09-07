//
//  RefWatchiOSApp.swift
//  RefWatchiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import SwiftUI
import SwiftData
import RefWatchCore

@main
struct RefWatchiOSApp: App {
    @StateObject private var router = AppRouter()
    // Built once during app init to avoid lazy/self init ordering issues
    private let modelContainer: ModelContainer?
    private let historyStore: MatchHistoryStoring

    @State private var matchVM: MatchViewModel
    @StateObject private var syncController: ConnectivitySyncController
    @StateObject private var syncDiagnostics = SyncDiagnosticsCenter()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Build SwiftData container and store with graceful fallback.
        //
        // Fallback Order (rationale):
        // 1) On-disk SwiftData (preferred): full persistence, query performance, and indexing.
        // 2) In-memory SwiftData: avoids startup crash if persistent container fails; keeps app usable.
        // 3) JSON store: final safety net to ensure critical features continue to work.
        let schema = Schema([CompletedMatchRecord.self])
        let container: ModelContainer?
        do {
            let config = ModelConfiguration(schema: schema)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            print("DEBUG: Failed to create SwiftData container: \(error). Falling back to in-memory configuration.")
            #endif
            // Attempt in-memory container as a soft-degraded fallback
            container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
        self.modelContainer = container
        if let container {
            self.historyStore = SwiftDataMatchHistoryStore(container: container, auth: NoopAuth(), importJSONOnFirstRun: true)
        } else {
            // Final safety: use JSON-backed store so the app remains functional
            #if DEBUG
            print("DEBUG: Using JSON MatchHistoryService fallback as SwiftData container could not be created.")
            #endif
            self.historyStore = MatchHistoryService()
        }

        // Initialize the MatchViewModel with the SwiftData-backed store
        _matchVM = State(initialValue: MatchViewModel(history: historyStore, haptics: IOSHaptics()))

        // Set up WatchConnectivity receiver
        _syncController = StateObject(wrappedValue: ConnectivitySyncController(history: historyStore, auth: NoopAuth()))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(matchViewModel: matchVM, historyStore: historyStore)
                .environmentObject(router)
                .environmentObject(syncDiagnostics)
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
