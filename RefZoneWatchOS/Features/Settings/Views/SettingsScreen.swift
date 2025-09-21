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
    @Bindable var settingsViewModel: SettingsViewModel
    // Persisted timer face selection used by TimerView host
    @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
    
    var body: some View {
        List {
            timerSection
            substitutionsSection
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
        Group {
            NavigationStack {
                SettingsScreen(settingsViewModel: SettingsViewModel())
            }
            .theme(DefaultTheme())
            .previewDisplayName("Standard")

            NavigationStack {
                SettingsScreen(settingsViewModel: SettingsViewModel())
            }
            .theme(DefaultTheme())
            .environment(\.sizeCategory, .accessibilityLarge)
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
