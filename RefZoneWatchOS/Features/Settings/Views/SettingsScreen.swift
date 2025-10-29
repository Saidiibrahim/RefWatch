//
//  SettingsScreen.swift
//  RefereeAssistant
//
//  Description: Main settings page where users can configure app preferences.
//

import SwiftUI
import Foundation
import RefWatchCore

struct SettingsScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var aggregateSync: AggregateSyncEnvironment
    @Bindable var settingsViewModel: SettingsViewModel
    // Persisted timer face selection used by TimerView host
    @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
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
        .padding(.vertical, theme.components.listRowVerticalInset)
        .background(theme.colors.backgroundPrimary)
        .navigationTitle("Settings")
    }
}

struct SettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let environment: AggregateSyncEnvironment = {
            let container = try! WatchAggregateContainerFactory.makeContainer(inMemory: true)
            let library = WatchAggregateLibraryStore(container: container)
            let chunk = WatchAggregateSnapshotChunkStore(container: container)
            let delta = WatchAggregateDeltaOutboxStore(container: container)
            let coordinator = WatchAggregateSyncCoordinator(
                libraryStore: library,
                chunkStore: chunk,
                deltaStore: delta
            )
            let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)
            return AggregateSyncEnvironment(
                libraryStore: library,
                chunkStore: chunk,
                deltaStore: delta,
                coordinator: coordinator,
                connectivity: connectivity
            )
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

private extension SettingsScreen {
    @ViewBuilder
    var timerSection: some View {
        Section {
            NavigationLink {
                TimerFaceSettingsView()
            } label: {
                SettingsNavigationRow(
                    title: "Timer Face",
                    value: TimerFaceStyle.parse(raw: timerFaceStyleRaw).displayName,
                    icon: "timer",
                    valueIdentifier: "timerFaceCurrentSelection"
                )
            }
            .accessibilityIdentifier("timerFaceRow")
            .listRowInsets(cardRowInsets)
            .listRowBackground(Color.clear)
        } header: {
            SettingsSectionHeader(title: "Timer")
        }
    }

    @ViewBuilder
    var disciplineSection: some View {
        Section {
            NavigationLink {
                MisconductTemplateSelectionView(settingsViewModel: settingsViewModel)
            } label: {
                SettingsNavigationRow(
                    title: "Misconduct Codes",
                    value: settingsViewModel.activeMisconductTemplate.name,
                    icon: "list.bullet.rectangle",
                    valueIdentifier: "misconductTemplateCurrentSelection"
                )
            }
            .accessibilityIdentifier("misconductTemplateRow")
            .listRowInsets(cardRowInsets)
            .listRowBackground(Color.clear)
        } header: {
            SettingsSectionHeader(title: "Discipline")
        }
    }

    @ViewBuilder
    var substitutionsSection: some View {
        Section {
            SettingsToggleRow(
                title: "Confirm Subs",
                subtitle: nil,
                icon: "checkmark.shield",
                isOn: $settingsViewModel.settings.confirmSubstitutions
            )
            .listRowInsets(cardRowInsets)
            .listRowBackground(Color.clear)

            ThemeCardContainer(role: .secondary, minHeight: 72) {
                Picker(selection: $settingsViewModel.settings.substitutionOrderPlayerOffFirst) {
                    Label("Player Off First", systemImage: "arrow.left.circle")
                        .tag(true)
                    Label("Player On First", systemImage: "arrow.right.circle")
                        .tag(false)
                } label: {
                    SettingsRowContent(
                        title: "Recording Order",
                        value: nil,
                        icon: "arrow.triangle.2.circlepath"
                    )
                }
                .pickerStyle(.navigationLink)
            }
            .listRowInsets(cardRowInsets)
            .listRowBackground(Color.clear)
        } header: {
            SettingsSectionHeader(title: "Substitutions")
        }
    }

    @ViewBuilder
    var syncSection: some View {
        Section {
            Button {
                requestManualSync()
            } label: {
                manualSyncRow
            }
            .buttonStyle(.plain)
            .disabled(isSyncButtonDisabled)
            .opacity(isSyncButtonDisabled && isSyncLoading == false ? 0.6 : 1)
            .listRowInsets(cardRowInsets)
            .listRowBackground(Color.clear)

            ThemeCardContainer(role: .secondary, minHeight: 72) {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(syncDetailHeading)
                        .font(theme.typography.cardHeadline)
                        .foregroundStyle(theme.colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(syncDetailBody)
                        .font(theme.typography.cardMeta)
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .listRowInsets(cardRowInsets)
            .listRowBackground(Color.clear)
        } header: {
            SettingsSectionHeader(title: "Sync")
        }
    }



    var cardRowInsets: EdgeInsets {
        EdgeInsets(
            top: theme.components.listRowVerticalInset,
            leading: 0,
            bottom: theme.components.listRowVerticalInset,
            trailing: 0
        )
    }

    var substitutionOrderLabel: String {
        settingsViewModel.settings.substitutionOrderPlayerOffFirst ? "Player Off First" : "Player On First"
    }

    var syncHeadline: String {
        let status = aggregateSync.status
        if syncRequestState == .cooldown && status.pendingSnapshotChunks == 0 {
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

    var syncDetailHeading: String {
        aggregateSync.status.requiresBackfill ? "Action required" : "Library overview"
    }

    var syncDetailBody: String {
        let status = aggregateSync.status
        var lines: [String] = []
        if let applied = status.lastSnapshotAppliedAt ?? status.lastSnapshotGeneratedAt {
            lines.append("Last synced \(relativeSyncString(from: applied))")
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
            HStack(spacing: theme.spacing.m) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundStyle(theme.colors.accentSecondary)

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("Resync Library")
                        .font(theme.typography.cardHeadline)
                        .foregroundStyle(theme.colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(syncHeadline)
                        .font(theme.typography.cardMeta)
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isSyncLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: aggregateSync.status.reachable ? "checkmark.circle" : "exclamationmark.circle")
                        .font(.title3)
                        .foregroundStyle(
                            aggregateSync.status.reachable
                            ? theme.colors.matchPositive
                            : theme.colors.accentSecondary
                        )
                }
            }
        }
    }

    private var isSyncLoading: Bool {
        syncRequestState == .requesting || aggregateSync.status.pendingSnapshotChunks > 0
    }

    private var isSyncButtonDisabled: Bool {
        syncRequestState != .idle || aggregateSync.status.pendingSnapshotChunks > 0
    }

    private func requestManualSync() {
        guard syncRequestState == .idle else { return }
        syncRequestState = .requesting
        aggregateSync.connectivity.requestManualAggregateSync()
        scheduleSyncCooldown()
    }

    private func scheduleSyncCooldown() {
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                if syncRequestState == .requesting {
                    syncRequestState = .cooldown
                }
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                // Reset only if still in cooldown to avoid stomping concurrent requests
                if syncRequestState != .idle {
                    syncRequestState = .idle
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
        Text(title.uppercased())
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
            .padding(.horizontal, theme.components.cardHorizontalPadding)
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
            HStack(spacing: theme.spacing.m) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(theme.colors.accentSecondary)
                }

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(title)
                        .font(theme.typography.cardHeadline)
                        .foregroundStyle(theme.colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let valueIdentifier {
                        Text(value)
                            .font(theme.typography.cardMeta)
                            .foregroundStyle(theme.colors.textSecondary)
                            .accessibilityIdentifier(valueIdentifier)
                    } else {
                        Text(value)
                            .font(theme.typography.cardMeta)
                            .foregroundStyle(theme.colors.textSecondary)
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
            Toggle(isOn: $isOn) {
                HStack(spacing: theme.spacing.m) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(theme.colors.accentSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: subtitleSpacing) {
                        Text(title)
                            .font(theme.typography.cardHeadline)
                            .foregroundStyle(theme.colors.textPrimary)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(theme.typography.cardMeta)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                }
            }
            .tint(theme.colors.matchPositive)
        }
    }

    private var subtitleSpacing: CGFloat {
        subtitle?.isEmpty == false ? theme.spacing.xs : 0
    }
}

struct SettingsRowContent: View {
    @Environment(\.theme) private var theme

    let title: String
    let value: String?
    let icon: String?

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            if let icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(theme.colors.accentSecondary)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(title)
                    .font(theme.typography.cardHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let value {
                    Text(value)
                        .font(theme.typography.cardMeta)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
        }
    }
}
