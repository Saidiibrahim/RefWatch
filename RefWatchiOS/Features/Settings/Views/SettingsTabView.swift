//
//  SettingsTabView.swift
//  RefWatchiOS
//
//  Settings tab for account, defaults, sync, and data management.
//

import SwiftUI
import RefWatchCore
import OSLog
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

struct SettingsTabView: View {
    let historyStore: MatchHistoryStoring
    let matchSyncController: MatchHistorySyncControlling?
    var scheduleStore: ScheduleStoring? = nil
    var teamStore: TeamLibraryStoring? = nil
    var competitionStore: CompetitionLibraryStoring? = nil
    var venueStore: VenueLibraryStoring? = nil
    var connectivityController: ConnectivitySyncController? = nil

    @ObservedObject private var auth: SupabaseAuthController
    @EnvironmentObject private var syncDiagnostics: SyncDiagnosticsCenter
    @EnvironmentObject private var authCoordinator: AuthenticationCoordinator

    @State private var defaultPeriod: Int = 45
    @State private var extraTime: Bool = false
    @State private var penaltyRounds: Int = 5
    @State private var connectivityStatusValue: String = "Unavailable"
    @State private var showWipeConfirm: Bool = false
    @State private var showAdvancedSyncDetails: Bool = false
    @StateObject private var authViewModel: SettingsAuthViewModel

    init(
        historyStore: MatchHistoryStoring,
        matchSyncController: MatchHistorySyncControlling? = nil,
        scheduleStore: ScheduleStoring? = nil,
        teamStore: TeamLibraryStoring? = nil,
        competitionStore: CompetitionLibraryStoring? = nil,
        venueStore: VenueLibraryStoring? = nil,
        connectivityController: ConnectivitySyncController? = nil,
        authController: SupabaseAuthController
    ) {
        self.historyStore = historyStore
        self.matchSyncController = matchSyncController
        self.scheduleStore = scheduleStore
        self.teamStore = teamStore
        self.competitionStore = competitionStore
        self.venueStore = venueStore
        self.connectivityController = connectivityController
        self._auth = ObservedObject(initialValue: authController)
        self._authViewModel = StateObject(wrappedValue: SettingsAuthViewModel(auth: authController))
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                librarySection
                diagnosticsSection
                defaultsSection
                syncSection
                dataSection
            }
            .navigationTitle("Settings")
            .alert("Authentication", isPresented: Binding(
                get: { authViewModel.alertMessage != nil },
                set: { newValue in if !newValue { authViewModel.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { authViewModel.alertMessage = nil }
            } message: {
                Text(authViewModel.alertMessage ?? "")
            }
            .confirmationDialog(
                "Wipe Local Data?",
                isPresented: $showWipeConfirm,
                titleVisibility: .visible
            ) {
                Button("Wipe Local Data", role: .destructive, action: wipeHistory)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove match history and scheduled matches stored locally on this iPhone. This action cannot be undone.")
            }
            .onAppear { updateConnectivityStatus(with: syncDiagnostics.aggregateStatus) }
            .onReceive(syncDiagnostics.$aggregateStatus) { status in
                updateConnectivityStatus(with: status)
            }
        }
    }
}

private extension SettingsTabView {
    var accountSection: some View {
        Section("Account") {
            signedInAccountContent
        }
    }

    @ViewBuilder
    var signedInAccountContent: some View {
        if case let .signedIn(_, _, displayName) = auth.state {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading) {
                        Text(displayName ?? "Signed in")
                            .font(.headline)
                        Text("You're connected with your RefWatch account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button(role: .destructive, action: signOut) {
                    if authViewModel.isPerformingAction {
                        ProgressView()
                    } else {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .disabled(authViewModel.isPerformingAction)
            }
        } else {
            // Fallback for unexpected states; redirect into the auth flow instead of showing a secondary CTA surface here.
            HStack(spacing: 8) {
                ProgressView()
                Text("Reopening sign-in…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .onAppear { authCoordinator.showSignIn() }
        }
    }

    var librarySection: some View {
        Section("Library") {
            NavigationLink {
                LibrarySettingsView(
                    teamStore: teamStore ?? InMemoryTeamLibraryStore(),
                    competitionStore: competitionStore ?? InMemoryCompetitionLibraryStore(),
                    venueStore: venueStore ?? InMemoryVenueLibraryStore()
                )
            } label: {
                Label("View Library", systemImage: "books.vertical")
            }
        }
    }

    var diagnosticsSection: some View {
        Group {
            if syncDiagnostics.showBanner, let message = syncDiagnostics.lastErrorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Sync Issue Detected").font(.headline)
                        }
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let context = syncDiagnostics.lastErrorContext {
                            Text(context)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button("Dismiss", action: syncDiagnostics.dismiss)
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    var defaultsSection: some View {
        Section("Defaults") {
            Stepper(value: $defaultPeriod, in: 30...60, step: 5) {
                LabeledContent("Regulation Period", value: "\(defaultPeriod) min")
            }
            Toggle("Extra Time Enabled", isOn: $extraTime)
            Stepper(value: $penaltyRounds, in: 3...10) {
                LabeledContent("Penalty Rounds", value: "\(penaltyRounds)")
            }
        }
    }

    var syncSection: some View {
        Section("Sync") {
            syncCard

#if DEBUG
            DisclosureGroup(isExpanded: $showAdvancedSyncDetails) {
                let status = aggregateStatus
                LabeledContent("Watch", value: connectivityStatusValue)
                LabeledContent("Queued Snapshots", value: "\(status.queuedSnapshots)")
                LabeledContent("Queued Deltas", value: "\(status.queuedDeltas)")
                LabeledContent("Pending Chunks", value: "\(status.pendingSnapshotChunks)")
                LabeledContent("Last Snapshot", value: formattedDate(status.lastSnapshot))
                let lastUpdated = status.lastUpdated == .distantPast ? nil : status.lastUpdated
                LabeledContent("Last Updated", value: formattedDate(lastUpdated))
            } label: {
                Text("Advanced sync details")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
#endif
        }
    }

    var dataSection: some View {
        Section("Data") {
            Button(role: .destructive) {
                AppLog.history.info("Prompting user to confirm local data wipe")
                showWipeConfirm = true
            } label: {
                Label("Wipe Local Data", systemImage: "trash")
            }
        }
    }

    func signOut() {
        Task { await authViewModel.signOut() }
    }

    func updateConnectivityStatus(with status: SyncDiagnosticsCenter.SyncComponentStatus) {
        switch status.connectivityStatus {
        case .reachable:
            if status.pendingSnapshotChunks > 0 {
                connectivityStatusValue = "Syncing (\(status.pendingSnapshotChunks))"
            } else if status.queuedDeltas > 0 {
                connectivityStatusValue = "Queued (\(status.queuedDeltas))"
            } else {
                connectivityStatusValue = "Reachable"
            }
        case .unreachable:
            if status.pendingSnapshotChunks > 0 {
                connectivityStatusValue = "Waiting (\(status.pendingSnapshotChunks))"
            } else if status.queuedDeltas > 0 {
                connectivityStatusValue = "Queued (\(status.queuedDeltas))"
            } else {
                connectivityStatusValue = "Unreachable"
            }
        case .unknown:
            connectivityStatusValue = status.signedIn ? "Unknown" : "Signed Out"
        }
    }

    var syncCard: some View {
        let status = aggregateStatus
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: syncIconName(for: status))
                    .font(.title3)
                    .foregroundStyle(syncIconColor(for: status))

                VStack(alignment: .leading, spacing: 2) {
                    Text(syncHeadline(for: status))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(syncSubheadline(for: status))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSyncing(status) {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }

            HStack {
                Label("Last sync", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedDate(status.lastSnapshot))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                AppLog.connectivity.info("User requested resync from Settings")
                connectivityController?.triggerManualAggregateSync()
            } label: {
                Label("Resync Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing(status))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    var aggregateStatus: SyncDiagnosticsCenter.SyncComponentStatus { syncDiagnostics.aggregateStatus }

    func isSyncing(_ status: SyncDiagnosticsCenter.SyncComponentStatus) -> Bool {
        status.pendingSnapshotChunks > 0
    }

    func syncHeadline(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> String {
        if status.connectivityStatus == .reachable {
            if status.pendingSnapshotChunks > 0 {
                return "Syncing to watch…"
            }
            if status.queuedSnapshots > 0 || status.queuedDeltas > 0 {
                return "Sending updates to watch"
            }
            return "Library up to date"
        }

        if status.queuedSnapshots > 0 || status.queuedDeltas > 0 || status.pendingSnapshotChunks > 0 {
            return "Waiting for watch"
        }
        return "Watch not reachable"
    }

    func syncSubheadline(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> String {
        if status.connectivityStatus == .reachable {
            if status.pendingSnapshotChunks > 0 {
                return "Applying updates now."
            }
            if status.queuedSnapshots > 0 || status.queuedDeltas > 0 {
                return "Updates are queued and sending."
            }
            return "RefWatch on watch has your latest library."
        }
        if status.queuedSnapshots > 0 || status.queuedDeltas > 0 || status.pendingSnapshotChunks > 0 {
            return "Bring your watch nearby and open RefWatch."
        }
        return "Open RefWatch on your watch to reconnect."
    }

    func syncIconName(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> String {
        if status.signedIn == false { return "exclamationmark.triangle.fill" }
        if status.pendingSnapshotChunks > 0 { return "arrow.triangle.2.circlepath" }
        if status.connectivityStatus == .reachable {
            return status.queuedSnapshots > 0 || status.queuedDeltas > 0 ? "arrow.up.circle" : "checkmark.circle.fill"
        }
        return "antenna.radiowaves.left.and.right.slash"
    }

    func syncIconColor(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> Color {
        if status.signedIn == false { return .orange }
        if status.pendingSnapshotChunks > 0 { return .blue }
        if status.connectivityStatus == .reachable {
            return status.queuedSnapshots > 0 || status.queuedDeltas > 0 ? .blue : .green
        }
        return .orange
    }

    func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    func wipeHistory() {
        do {
            try historyStore.wipeAll()
            try scheduleStore?.wipeAll()
        } catch {
            AppLog.history.error("Failed to wipe local history: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#if DEBUG
@MainActor
private final class PreviewMatchHistoryStore: MatchHistoryStoring {
    func loadAll() throws -> [CompletedMatch] { [] }
    func save(_ match: CompletedMatch) throws { }
    func delete(id: UUID) throws { }
    func wipeAll() throws { }
}

#Preview("Settings") {
    let authController = SupabaseAuthController(clientProvider: SupabaseClientProvider.shared)
    let diagnostics = SyncDiagnosticsCenter()
    let coordinator = AuthenticationCoordinator(authController: authController)

    return SettingsTabView(
        historyStore: PreviewMatchHistoryStore(),
        scheduleStore: InMemoryScheduleStore(),
        teamStore: InMemoryTeamLibraryStore(),
        competitionStore: InMemoryCompetitionLibraryStore(),
        venueStore: InMemoryVenueLibraryStore(),
        connectivityController: nil,
        authController: authController
    )
    .environmentObject(diagnostics)
    .environmentObject(coordinator)
}
#endif
