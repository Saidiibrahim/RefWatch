//
//  SettingsScreen.swift
//  RefereeAssistant
//
//  Description: Main settings page where users can configure app preferences.
//

import SwiftUI
import RefWatchCore

struct SettingsScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var aggregateSync: AggregateSyncEnvironment
    @Bindable var settingsViewModel: SettingsViewModel
    // Persisted timer face selection used by TimerView host
    @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
    
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
                    value: settingsViewModel.activeMisconductTemplate.displayName,
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
                aggregateSync.connectivity.requestManualAggregateSync()
            } label: {
                SettingsNavigationRow(
                    title: "Resync Library",
                    value: syncHeadline,
                    icon: "arrow.clockwise",
                    valueIdentifier: nil
                )
            }
            .buttonStyle(.plain)
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
        if status.pendingSnapshotChunks > 0 {
            return "Applying snapshot…"
        }
        if status.queuedSnapshots > 0 || status.queuedDeltas > 0 {
            return "Waiting on iPhone"
        }
        return status.reachable ? "Up to date" : "Awaiting Connection"
    }

    var syncDetailHeading: String {
        aggregateSync.status.requiresBackfill ? "Backfill required" : "Library status"
    }

    var syncDetailBody: String {
        let status = aggregateSync.status
        var lines: [String] = []
        let connectivity = status.lastConnectivityStatusRaw ?? "unknown"
        lines.append("Connectivity: \(connectivity.capitalized)")
        lines.append("Reachable: \(status.reachable ? "Yes" : "No")")
        lines.append("Pending chunks: \(status.pendingSnapshotChunks)")
        lines.append("Queued snapshots: \(status.queuedSnapshots)")
        lines.append("Queued deltas: \(status.queuedDeltas)")
        if let lastSnapshot = status.lastSnapshotGeneratedAt {
            lines.append("Last snapshot: \(lastSnapshot.formatted(date: .abbreviated, time: .shortened))")
        } else {
            lines.append("Last snapshot: Never")
        }
        if let supabase = status.lastSupabaseSync {
            lines.append("Last Supabase sync: \(supabase.formatted(date: .abbreviated, time: .shortened))")
        }
        if status.requiresBackfill {
            lines.append("Backfill pending: Yes")
        }
        return lines.joined(separator: "\n")
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
