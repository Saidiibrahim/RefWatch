//
//  SettingsTabView.swift
//  RefWatchiOS
//
//  Settings tab for account, defaults, sync, and data management.
//

import OSLog
import RefWatchCore
import SwiftUI
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

struct SettingsTabView: View {
  let historyStore: MatchHistoryStoring
  let matchSyncController: MatchHistorySyncControlling?
  var scheduleStore: ScheduleStoring?
  var teamStore: TeamLibraryStoring?
  var competitionStore: CompetitionLibraryStoring?
  var venueStore: VenueLibraryStoring?
  var connectivityController: ConnectivitySyncController?

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
    authController: SupabaseAuthController)
  {
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
        get: { self.authViewModel.alertMessage != nil },
        set: { newValue in if !newValue { self.authViewModel.alertMessage = nil } }
      )) {
        Button("OK", role: .cancel) { self.authViewModel.alertMessage = nil }
      } message: {
        Text(self.authViewModel.alertMessage ?? "")
      }
      .confirmationDialog(
        "Wipe Local Data?",
        isPresented: self.$showWipeConfirm,
        titleVisibility: .visible)
      {
        Button("Wipe Local Data", role: .destructive, action: wipeHistory)
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "This will permanently remove match history and scheduled matches " +
            "stored locally on this iPhone. This action cannot be undone.")
      }
      .onAppear { updateConnectivityStatus(with: self.syncDiagnostics.aggregateStatus) }
      .onReceive(self.syncDiagnostics.$aggregateStatus) { status in
        updateConnectivityStatus(with: status)
      }
    }
  }
}

extension SettingsTabView {
  private var accountSection: some View {
    Section("Account") {
      self.signedInAccountContent
    }
  }

  @ViewBuilder
  private var signedInAccountContent: some View {
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
        Button(role: .destructive, action: self.signOut) {
          if self.authViewModel.isPerformingAction {
            ProgressView()
          } else {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
          }
        }
        .disabled(self.authViewModel.isPerformingAction)
      }
    } else {
      // Fallback for unexpected states; redirect into the auth flow instead of
      // showing a secondary CTA surface here.
      HStack(spacing: 8) {
        ProgressView()
        Text("Reopening sign-in…")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .onAppear { self.authCoordinator.showSignIn() }
    }
  }

  private var librarySection: some View {
    Section("Library") {
      NavigationLink {
        LibrarySettingsView(
          teamStore: self.teamStore ?? InMemoryTeamLibraryStore(),
          competitionStore: self.competitionStore ?? InMemoryCompetitionLibraryStore(),
          venueStore: self.venueStore ?? InMemoryVenueLibraryStore())
      } label: {
        Label("View Library", systemImage: "books.vertical")
      }
    }
  }

  private var diagnosticsSection: some View {
    Group {
      if self.syncDiagnostics.showBanner, let message = syncDiagnostics.lastErrorMessage {
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
            Button("Dismiss", action: self.syncDiagnostics.dismiss)
              .buttonStyle(.bordered)
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private var defaultsSection: some View {
    Section("Defaults") {
      Stepper(value: self.$defaultPeriod, in: 30...60, step: 5) {
        LabeledContent("Regulation Period", value: "\(self.defaultPeriod) min")
      }
      Toggle("Extra Time Enabled", isOn: self.$extraTime)
      Stepper(value: self.$penaltyRounds, in: 3...10) {
        LabeledContent("Penalty Rounds", value: "\(self.penaltyRounds)")
      }
    }
  }

  private var syncSection: some View {
    Section("Sync") {
      self.syncCard

      #if DEBUG
      DisclosureGroup(isExpanded: self.$showAdvancedSyncDetails) {
        let status = self.aggregateStatus
        LabeledContent("Watch", value: self.connectivityStatusValue)
        LabeledContent("Queued Snapshots", value: "\(status.queuedSnapshots)")
        LabeledContent("Queued Deltas", value: "\(status.queuedDeltas)")
        LabeledContent("Pending Chunks", value: "\(status.pendingSnapshotChunks)")
        LabeledContent("Last Snapshot", value: self.formattedDate(status.lastSnapshot))
        let lastUpdated = status.lastUpdated == .distantPast ? nil : status.lastUpdated
        LabeledContent("Last Updated", value: self.formattedDate(lastUpdated))
      } label: {
        Text("Advanced sync details")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      #endif
    }
  }

  private var dataSection: some View {
    Section("Data") {
      Button(role: .destructive) {
        AppLog.history.info("Prompting user to confirm local data wipe")
        self.showWipeConfirm = true
      } label: {
        Label("Wipe Local Data", systemImage: "trash")
      }
    }
  }

  private func signOut() {
    Task { await self.authViewModel.signOut() }
  }

  private func updateConnectivityStatus(with status: SyncDiagnosticsCenter.SyncComponentStatus) {
    switch status.connectivityStatus {
    case .reachable:
      if status.pendingSnapshotChunks > 0 {
        self.connectivityStatusValue = "Syncing (\(status.pendingSnapshotChunks))"
      } else if status.queuedDeltas > 0 {
        self.connectivityStatusValue = "Queued (\(status.queuedDeltas))"
      } else {
        self.connectivityStatusValue = "Reachable"
      }
    case .unreachable:
      if status.pendingSnapshotChunks > 0 {
        self.connectivityStatusValue = "Waiting (\(status.pendingSnapshotChunks))"
      } else if status.queuedDeltas > 0 {
        self.connectivityStatusValue = "Queued (\(status.queuedDeltas))"
      } else {
        self.connectivityStatusValue = "Unreachable"
      }
    case .unknown:
      self.connectivityStatusValue = status.signedIn ? "Unknown" : "Signed Out"
    }
  }

  private var syncCard: some View {
    let status = self.aggregateStatus
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: self.syncIconName(for: status))
          .font(.title3)
          .foregroundStyle(self.syncIconColor(for: status))

        VStack(alignment: .leading, spacing: 2) {
          Text(self.syncHeadline(for: status))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(self.syncSubheadline(for: status))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if self.isSyncing(status) {
          ProgressView()
            .progressViewStyle(.circular)
        }
      }

      HStack {
        Label("Last sync", systemImage: "clock.arrow.circlepath")
          .labelStyle(.titleAndIcon)
          .foregroundStyle(.secondary)
        Spacer()
        Text(self.formattedDate(status.lastSnapshot))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Button {
        AppLog.connectivity.info("User requested resync from Settings")
        self.connectivityController?.triggerManualAggregateSync()
      } label: {
        Label("Resync Now", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.borderedProminent)
      .disabled(self.isSyncing(status))
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color(.secondarySystemGroupedBackground)))
    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    .listRowBackground(Color.clear)
  }

  private var aggregateStatus: SyncDiagnosticsCenter.SyncComponentStatus { self.syncDiagnostics.aggregateStatus }

  private func isSyncing(_ status: SyncDiagnosticsCenter.SyncComponentStatus) -> Bool {
    status.pendingSnapshotChunks > 0
  }

  private func syncHeadline(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> String {
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

  private func syncSubheadline(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> String {
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

  private func syncIconName(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> String {
    if status.signedIn == false { return "exclamationmark.triangle.fill" }
    if status.pendingSnapshotChunks > 0 { return "arrow.triangle.2.circlepath" }
    if status.connectivityStatus == .reachable {
      return status.queuedSnapshots > 0 || status.queuedDeltas > 0 ? "arrow.up.circle" : "checkmark.circle.fill"
    }
    return "antenna.radiowaves.left.and.right.slash"
  }

  private func syncIconColor(for status: SyncDiagnosticsCenter.SyncComponentStatus) -> Color {
    if status.signedIn == false { return .orange }
    if status.pendingSnapshotChunks > 0 { return .blue }
    if status.connectivityStatus == .reachable {
      return status.queuedSnapshots > 0 || status.queuedDeltas > 0 ? .blue : .green
    }
    return .orange
  }

  private func formattedDate(_ date: Date?) -> String {
    guard let date else { return "Never" }
    return date.formatted(date: .abbreviated, time: .shortened)
  }

  private func wipeHistory() {
    do {
      try self.historyStore.wipeAll()
      try self.scheduleStore?.wipeAll()
    } catch {
      AppLog.history.error("Failed to wipe local history: \(error.localizedDescription, privacy: .public)")
    }
  }
}

#if DEBUG
@MainActor
private final class PreviewMatchHistoryStore: MatchHistoryStoring {
  func loadAll() throws -> [CompletedMatch] { [] }
  func save(_ match: CompletedMatch) throws {}
  func delete(id: UUID) throws {}
  func wipeAll() throws {}
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
    authController: authController)
    .environmentObject(diagnostics)
    .environmentObject(coordinator)
}
#endif
