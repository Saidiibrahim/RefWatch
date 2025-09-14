//
//  SettingsTabView.swift
//  RefZoneiOS
//
//  Settings tab for account, defaults, sync, and data management
//

import SwiftUI
import RefWatchCore
import Clerk
import OSLog

struct SettingsTabView: View {
    let historyStore: MatchHistoryStoring
    var scheduleStore: ScheduleStoring? = nil
    var teamStore: TeamLibraryStoring? = nil
    @EnvironmentObject private var syncDiagnostics: SyncDiagnosticsCenter
    @Environment(\.clerk) private var clerk
    @State private var defaultPeriod: Int = 45
    @State private var extraTime: Bool = false
    @State private var penaltyRounds: Int = 5
    @State private var showingInfoAlert = false
    @State private var infoMessage: String = ""
    @State private var activeSheet: ActiveSheet? = nil
    @State private var connectivityStatusValue: String = "Unavailable"
    @State private var showWipeConfirm: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if clerk.user != nil {
                        HStack(spacing: 12) {
                            UserButton()
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading) {
                                Text(clerk.user?.firstName ?? clerk.user?.username ?? "Signed in")
                                    .font(.headline)
                                Text("Manage your profile or sign out")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Manage") { activeSheet = .profile }
                                .buttonStyle(.bordered)
                        }
                        Text("Signing out keeps local data. New history will not be tagged with your account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button { activeSheet = .auth } label: {
                            Label("Sign in", systemImage: "person.crop.circle.badge.plus")
                        }
                        Text("Sign in on iPhone to tag new match history to your account. You can continue offline without signing in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Library") {
                    NavigationLink {
                        if let teamStore {
                            LibrarySettingsView(teamStore: teamStore)
                        } else {
                            LibrarySettingsView(teamStore: InMemoryTeamLibraryStore())
                        }
                    } label: {
                        Label("View Library", systemImage: "books.vertical")
                    }
                }
                if syncDiagnostics.showBanner, let msg = syncDiagnostics.lastErrorMessage {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sync Issue Detected").font(.headline)
                                Text(msg).font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let ctx = syncDiagnostics.lastErrorContext {
                                    Text(ctx).font(.caption2).foregroundStyle(.secondary)
                                }
                                Button("Dismiss") { syncDiagnostics.dismiss() }
                                    .buttonStyle(.bordered)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Defaults") {
                    Stepper(value: $defaultPeriod, in: 30...60, step: 5) {
                        LabeledContent("Regulation Period", value: "\(defaultPeriod) min")
                    }
                    Toggle("Extra Time Enabled", isOn: $extraTime)
                    Stepper(value: $penaltyRounds, in: 3...10) {
                        LabeledContent("Penalty Rounds", value: "\(penaltyRounds)")
                    }
                }

                Section("Sync") {
                    LabeledContent("Watch", value: connectivityStatusValue)
                    Button {
                        AppLog.connectivity.info("User requested resync from Settings")
                    } label: { Label("Resync Now", systemImage: "arrow.clockwise") }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        AppLog.history.info("Prompting user to confirm local data wipe")
                        showWipeConfirm = true
                    } label: { Label("Wipe Local Data", systemImage: "trash") }
                }

            }
            .navigationTitle("Settings")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .auth:
                    AuthView()
                        .presentationDetents([.large])
                case .profile:
                    UserProfileView()
                        .presentationDetents([.large])
                }
            }
            // Dismiss any presented clerk UI when auth state changes
            .onChange(of: clerk.user?.id) { _ in
                activeSheet = nil
            }
            .alert("Info", isPresented: $showingInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(infoMessage)
            }
            .confirmationDialog(
                "Wipe Local Data?",
                isPresented: $showWipeConfirm,
                titleVisibility: .visible
            ) {
                Button("Wipe Local Data", role: .destructive) {
                    wipeHistory()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove completed matches and your scheduled matches stored locally on this iPhone. This action cannot be undone.")
            }
            .onAppear { refreshConnectivityStatus() }
        }
    }
}

private extension SettingsTabView {
    enum ActiveSheet: Identifiable { case auth, profile
        var id: String { self == .auth ? "auth" : "profile" }
    }

    func wipeHistory() {
        do {
            try historyStore.wipeAll()
            scheduleStore?.wipeAll()
            AppLog.history.info("Wiped local data: history + schedule")
            infoMessage = "Local match history wiped."
            showingInfoAlert = true
        } catch {
            AppLog.history.error("Failed to wipe data: \(error.localizedDescription, privacy: .public)")
            infoMessage = "Failed to wipe data: \(error.localizedDescription)"
            showingInfoAlert = true
        }
    }

    func refreshConnectivityStatus() {
        #if canImport(WatchConnectivity)
        let client = ConnectivityClient.shared
        if !client.isSupported {
            connectivityStatusValue = "Unavailable"
        } else if !client.isPaired {
            connectivityStatusValue = "Not Paired"
        } else if !client.isWatchAppInstalled {
            connectivityStatusValue = "App Not Installed"
        } else if client.isReachable {
            connectivityStatusValue = "Connected"
        } else {
            connectivityStatusValue = "Paired"
        }
        #else
        connectivityStatusValue = "Unavailable"
        #endif
    }
}

#Preview {
    SettingsTabView(historyStore: MatchHistoryService(), scheduleStore: ScheduleService(), teamStore: InMemoryTeamLibraryStore())
        .environmentObject(SyncDiagnosticsCenter())
}
