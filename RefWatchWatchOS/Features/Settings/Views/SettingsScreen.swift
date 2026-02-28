//
//  SettingsScreen.swift
//  RefereeAssistant
//
//  Description: Main settings page where users can configure app preferences.
//

import Foundation
import RefWatchCore
import SwiftUI

struct SettingsScreen: View {
  @Environment(\.theme) private var theme
  @EnvironmentObject private var aggregateSync: AggregateSyncEnvironment
  @Bindable var settingsViewModel: SettingsViewModel
  // Persisted timer face selection used by TimerView host
  @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
  // Persisted countdown enabled setting
  @AppStorage("countdown_enabled") private var countdownEnabled: Bool = true
  @State private var syncRequestState: SyncRequestState = .idle

  private enum SyncRequestState {
    case idle
    case requesting
    case cooldown
  }

  var body: some View {
    List {
      timerSection
      disciplineSection
      substitutionsSection
      syncSection
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .padding(.vertical, self.theme.components.listRowVerticalInset)
    .background(self.theme.colors.backgroundPrimary)
    .navigationTitle("Settings")
  }
}

struct SettingsScreen_Previews: PreviewProvider {
  static var previews: some View {
    let environment: AggregateSyncEnvironment = {
      guard let container = try? WatchAggregateContainerFactory.makeContainer(inMemory: true) else {
        fatalError("Failed to create preview aggregate container")
      }
      let library = WatchAggregateLibraryStore(container: container)
      let chunk = WatchAggregateSnapshotChunkStore(container: container)
      let delta = WatchAggregateDeltaOutboxStore(container: container)
      let coordinator = WatchAggregateSyncCoordinator(
        libraryStore: library,
        chunkStore: chunk,
        deltaStore: delta)
      let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)
      return AggregateSyncEnvironment(
        libraryStore: library,
        chunkStore: chunk,
        deltaStore: delta,
        coordinator: coordinator,
        connectivity: connectivity)
    }()

    Group {
      NavigationStack {
        SettingsScreen(settingsViewModel: SettingsViewModel())
      }
      .theme(DefaultTheme())
      .environmentObject(environment)
      .previewDisplayName("Standard")

      NavigationStack {
        SettingsScreen(settingsViewModel: SettingsViewModel())
      }
      .theme(DefaultTheme())
      .environment(\.sizeCategory, .accessibilityLarge)
      .environmentObject(environment)
      .previewDisplayName("Accessibility Large")
    }
  }
}

// TimerFaceSettingsView moved to its own file for clarity and convention.

extension SettingsScreen {
  @ViewBuilder
  private var timerSection: some View {
    Section {
      NavigationLink {
        TimerFaceSettingsView()
      } label: {
        SettingsNavigationRow(
          title: "Timer Face",
          value: TimerFaceStyle.parse(raw: self.timerFaceStyleRaw).displayName,
          icon: "timer",
          valueIdentifier: "timerFaceCurrentSelection")
      }
      .accessibilityIdentifier("timerFaceRow")
      .listRowInsets(self.cardRowInsets)
      .listRowBackground(Color.clear)

      SettingsToggleRow(
        title: "Countdown",
        subtitle: "Show countdown before start",
        icon: "clock.arrow.circlepath",
        isOn: self.$countdownEnabled)
        .accessibilityIdentifier("countdownToggleRow")
        .listRowInsets(self.cardRowInsets)
        .listRowBackground(Color.clear)
    } header: {
      SettingsSectionHeader(title: "Timer")
    }
  }

  @ViewBuilder
  private var disciplineSection: some View {
    Section {
      NavigationLink {
        MisconductTemplateSelectionView(settingsViewModel: self.settingsViewModel)
      } label: {
        SettingsNavigationRow(
          title: "Misconduct Codes",
          value: self.misconductTemplateSummary,
          icon: "list.bullet.rectangle",
          valueIdentifier: "misconductTemplateCurrentSelection")
      }
      .accessibilityIdentifier("misconductTemplateRow")
      .listRowInsets(self.cardRowInsets)
      .listRowBackground(Color.clear)
    } header: {
      SettingsSectionHeader(title: "Discipline")
    }
  }

  @ViewBuilder
  private var substitutionsSection: some View {
    Section {
      SettingsToggleRow(
        title: "Confirm Subs",
        subtitle: nil,
        icon: "checkmark.shield",
        isOn: self.$settingsViewModel.settings.confirmSubstitutions)
        .listRowInsets(self.cardRowInsets)
        .listRowBackground(Color.clear)

      ThemeCardContainer(role: .secondary, minHeight: 72) {
        Picker(selection: self.$settingsViewModel.settings.substitutionOrderPlayerOffFirst) {
          Label("Player Off First", systemImage: "arrow.left.circle")
            .tag(true)
          Label("Player On First", systemImage: "arrow.right.circle")
            .tag(false)
        } label: {
          SettingsRowContent(
            title: "Recording Order",
            value: nil,
            icon: "arrow.triangle.2.circlepath")
        }
        .pickerStyle(.navigationLink)
      }
      .listRowInsets(self.cardRowInsets)
      .listRowBackground(Color.clear)
    } header: {
      SettingsSectionHeader(title: "Substitutions")
    }
  }

  @ViewBuilder
  private var syncSection: some View {
    Section {
      Button {
        self.requestManualSync()
      } label: {
        self.manualSyncRow
      }
      .buttonStyle(.plain)
      .disabled(self.isSyncButtonDisabled)
      .opacity(self.isSyncButtonDisabled && self.isSyncLoading == false ? 0.6 : 1)
      .listRowInsets(self.cardRowInsets)
      .listRowBackground(Color.clear)

      ThemeCardContainer(role: .secondary, minHeight: 72) {
        VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
          Text(self.syncDetailHeading)
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(self.syncDetailBody)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .listRowInsets(self.cardRowInsets)
      .listRowBackground(Color.clear)
    } header: {
      SettingsSectionHeader(title: "Sync")
    }
  }

  private var cardRowInsets: EdgeInsets {
    EdgeInsets(
      top: self.theme.components.listRowVerticalInset,
      leading: 0,
      bottom: self.theme.components.listRowVerticalInset,
      trailing: 0)
  }

  private var misconductTemplateSummary: String {
    self.settingsViewModel.activeMisconductTemplate.name
  }

  private var substitutionOrderLabel: String {
    self.settingsViewModel.settings.substitutionOrderPlayerOffFirst ? "Player Off First" : "Player On First"
  }

  private var syncHeadline: String {
    let status = self.aggregateSync.status
    if self.syncRequestState == .cooldown && status.pendingSnapshotChunks == 0 {
      return "Sync requested"
    }
    if status.pendingSnapshotChunks > 0 {
      return "Syncing…"
    }
    if status.queuedSnapshots > 0 || status.queuedDeltas > 0 {
      return "Waiting on iPhone"
    }
    return status.reachable ? "Library up to date" : "Awaiting connection"
  }

  private var syncDetailHeading: String {
    self.aggregateSync.status.requiresBackfill ? "Action required" : "Library overview"
  }

  private var syncDetailBody: String {
    let status = self.aggregateSync.status
    var lines: [String] = []
    if let applied = status.lastSnapshotAppliedAt ?? status.lastSnapshotGeneratedAt {
      lines.append("Last synced \(self.relativeSyncString(from: applied))")
    } else {
      lines.append("No sync received yet")
    }
    if status.pendingSnapshotChunks > 0 {
      lines.append("Applying updates from iPhone")
    } else if status.queuedSnapshots > 0 || status.queuedDeltas > 0 {
      lines.append("Waiting for iPhone response")
    } else if status.requiresBackfill {
      lines.append("Backfill needed from iPhone")
    } else {
      lines.append("Library looks ready")
    }
    lines.append(status.reachable ? "iPhone reachable" : "iPhone unavailable")
    return lines.joined(separator: "\n")
  }

  @ViewBuilder
  private var manualSyncRow: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: self.theme.spacing.m) {
        Image(systemName: "arrow.clockwise")
          .font(.title2)
          .foregroundStyle(self.theme.colors.accentSecondary)

        VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
          Text("Resync Library")
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(self.syncHeadline)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if self.isSyncLoading {
          ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(0.7)
        } else {
          Image(systemName: self.aggregateSync.status.reachable ? "checkmark.circle" : "exclamationmark.circle")
            .font(.title3)
            .foregroundStyle(
              self.aggregateSync.status.reachable
                ? self.theme.colors.matchPositive
                : self.theme.colors.accentSecondary)
        }
      }
    }
  }

  private var isSyncLoading: Bool {
    self.syncRequestState == .requesting || self.aggregateSync.status.pendingSnapshotChunks > 0
  }

  private var isSyncButtonDisabled: Bool {
    self.syncRequestState != .idle || self.aggregateSync.status.pendingSnapshotChunks > 0
  }

  private func requestManualSync() {
    guard self.syncRequestState == .idle else { return }
    self.syncRequestState = .requesting
    self.aggregateSync.connectivity.requestManualAggregateSync()
    self.scheduleSyncCooldown()
  }

  private func scheduleSyncCooldown() {
    Task {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      await MainActor.run {
        if self.syncRequestState == .requesting {
          self.syncRequestState = .cooldown
        }
      }
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      await MainActor.run {
        // Reset only if still in cooldown to avoid stomping concurrent requests
        if self.syncRequestState != .idle {
          self.syncRequestState = .idle
        }
      }
    }
  }

  private func relativeSyncString(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

struct SettingsSectionHeader: View {
  @Environment(\.theme) private var theme

  let title: String

  var body: some View {
    Text(self.title.uppercased())
      .font(self.theme.typography.cardMeta)
      .foregroundStyle(self.theme.colors.textSecondary)
      .padding(.horizontal, self.theme.components.cardHorizontalPadding)
  }
}

struct SettingsNavigationRow: View {
  @Environment(\.theme) private var theme

  let title: String
  let value: String
  let icon: String?
  let valueIdentifier: String?

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: self.theme.spacing.m) {
        if let icon {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(self.theme.colors.accentSecondary)
        }

        VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
          Text(self.title)
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

          if let valueIdentifier {
            Text(self.value)
              .font(self.theme.typography.cardMeta)
              .foregroundStyle(self.theme.colors.textSecondary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier(valueIdentifier)
          } else {
            Text(self.value)
              .font(self.theme.typography.cardMeta)
              .foregroundStyle(self.theme.colors.textSecondary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }
}

struct SettingsToggleRow: View {
  @Environment(\.theme) private var theme

  let title: String
  let subtitle: String?
  let icon: String?
  @Binding var isOn: Bool

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      Toggle(isOn: self.$isOn) {
        HStack(spacing: self.theme.spacing.m) {
          if let icon {
            Image(systemName: icon)
              .font(.title2)
              .foregroundStyle(self.theme.colors.accentSecondary)
          }

          VStack(alignment: .leading, spacing: self.subtitleSpacing) {
            Text(self.title)
              .font(self.theme.typography.cardHeadline)
              .foregroundStyle(self.theme.colors.textPrimary)
              .lineLimit(1)
              .minimumScaleFactor(0.72)
              .allowsTightening(true)
              .multilineTextAlignment(.leading)

            if let subtitle, !subtitle.isEmpty {
              Text(subtitle)
                .font(self.theme.typography.cardMeta)
                .foregroundStyle(self.theme.colors.textSecondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .tint(self.theme.colors.matchPositive)
    }
  }

  private var subtitleSpacing: CGFloat {
    self.subtitle?.isEmpty == false ? self.theme.spacing.xs : 0
  }
}

struct SettingsRowContent: View {
  @Environment(\.theme) private var theme

  let title: String
  let value: String?
  let icon: String?

  var body: some View {
    HStack(spacing: self.theme.spacing.m) {
      if let icon {
        Image(systemName: icon)
          .font(.title2)
          .foregroundStyle(self.theme.colors.accentSecondary)
      }

      VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
        Text(self.title)
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let value {
          Text(value)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
      }
    }
  }
}
