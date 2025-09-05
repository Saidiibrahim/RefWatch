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
    private let modelContainer: ModelContainer
    private let historyStore: SwiftDataMatchHistoryStore

    @State private var matchVM: MatchViewModel
    private var iosSync: IOSConnectivitySyncClient?

    init() {
        // Build SwiftData container and store
        let schema = Schema([CompletedMatchRecord.self])
        let config = ModelConfiguration(schema: schema)
        let container = try! ModelContainer(for: schema, configurations: [config])
        self.modelContainer = container
        let store = SwiftDataMatchHistoryStore(container: container, auth: NoopAuth(), importJSONOnFirstRun: true)
        self.historyStore = store

        // Initialize the MatchViewModel with the SwiftData-backed store
        _matchVM = State(initialValue: MatchViewModel(history: store, haptics: IOSHaptics()))

        // Set up WatchConnectivity receiver
        let sync = IOSConnectivitySyncClient(history: store, auth: NoopAuth())
        sync.activate()
        self.iosSync = sync
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(matchViewModel: matchVM, historyStore: historyStore)
                .environmentObject(router)
        }
    }
}
