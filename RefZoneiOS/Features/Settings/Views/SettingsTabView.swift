//
//  SettingsTabView.swift
//  RefZoneiOS
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

    @ObservedObject private var auth: SupabaseAuthController
    @EnvironmentObject private var syncDiagnostics: SyncDiagnosticsCenter
    @EnvironmentObject private var authCoordinator: AuthenticationCoordinator

    @State private var defaultPeriod: Int = 45
    @State private var extraTime: Bool = false
    @State private var penaltyRounds: Int = 5
    @State private var connectivityStatusValue: String = "Unavailable"
    @State private var showWipeConfirm: Bool = false
    @StateObject private var authViewModel: SettingsAuthViewModel

    init(
        historyStore: MatchHistoryStoring,
        matchSyncController: MatchHistorySyncControlling? = nil,
        scheduleStore: ScheduleStoring? = nil,
        teamStore: TeamLibraryStoring? = nil,
        competitionStore: CompetitionLibraryStoring? = nil,
        venueStore: VenueLibraryStoring? = nil,
        authController: SupabaseAuthController
    ) {
        self.historyStore = historyStore
        self.matchSyncController = matchSyncController
        self.scheduleStore = scheduleStore
        self.teamStore = teamStore
        self.competitionStore = competitionStore
        self.venueStore = venueStore
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
            .onAppear(perform: refreshConnectivityStatus)
        }
    }
}

private extension SettingsTabView {
    var accountSection: some View {
        Section("Account") {
            switch auth.state {
            case .signedOut:
                VStack(alignment: .leading, spacing: 16) {
                    Text("You're not signed in")
                        .font(.headline)

                    Text("RefZone on iPhone now requires a signed-in account. Sign in to access match history, schedules, trends, and team management.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        authCoordinator.showSignIn()
                    } label: {
                        Label("Sign In", systemImage: "person.crop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        authCoordinator.showSignUp()
                    } label: {
                        Label("Create Account", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Text("Want a refresher on what's included? Review the Welcome screen for a quick overview of what signing in unlocks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Show Welcome Again") {
                        authCoordinator.showWelcome()
                    }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            case let .signedIn(_, _, displayName):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(displayName ?? "Signed in")
                                .font(.headline)
                            Text("You're connected with your RefZone account.")
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
            }
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
            LabeledContent("Watch", value: connectivityStatusValue)
            Button {
                AppLog.connectivity.info("User requested resync from Settings")
            } label: {
                Label("Resync Now", systemImage: "arrow.clockwise")
            }
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

    func refreshConnectivityStatus() {
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            switch session.activationState {
            case .notActivated:
                connectivityStatusValue = "Not Activated"
            case .inactive:
                connectivityStatusValue = "Inactive"
            case .activated:
                connectivityStatusValue = session.isReachable ? "Reachable" : "Activated"
            @unknown default:
                connectivityStatusValue = "Unknown"
            }
        } else {
            connectivityStatusValue = "Unsupported"
        }
        #else
        connectivityStatusValue = "Unavailable"
        #endif
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
        authController: authController
    )
    .environmentObject(diagnostics)
    .environmentObject(coordinator)
}
#endif
