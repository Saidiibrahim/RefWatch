//
//  StartMatchScreen.swift
//  RefereeAssistant
//
//  Description: Displays two options: "From Library" and "Create".
//

import SwiftUI
import RefWatchCore

struct StartMatchScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: theme.components.listVerticalSpacing) {
                NavigationLink {
                    SavedMatchesView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                } label: {
                    MenuCard(
                        title: "Select Match",
                        subtitle: "Choose from recent fixtures",
                        icon: "folder",
                        tint: theme.colors.accentSecondary,
                        accessoryIcon: "chevron.forward",
                        minHeight: 88,
                        role: .secondary
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    matchViewModel.resetMatch()
                })

                NavigationLink {
                    CreateMatchView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                } label: {
                    MenuCard(
                        title: "Create Match",
                        subtitle: "Set duration, periods, and extras",
                        icon: "plus.circle.fill",
                        tint: theme.colors.textInverted,
                        accessoryIcon: "chevron.forward",
                        minHeight: 88,
                        role: .positive
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    matchViewModel.resetMatch()
                })
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .padding(.vertical, theme.components.listRowVerticalInset * 2)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Start Match")
        .onChange(of: lifecycle.state) { newValue in
            if newValue != .idle {
                dismiss()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if lifecycle.state == .idle {
                    Button {
                        modeSwitcherPresentation.wrappedValue = true
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
    }
}

// View for creating a new match with settings
struct CreateMatchView: View {
    @Environment(\.theme) private var theme
    @Bindable var matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                durationRow
                periodsRow
                halfTimeRow
            }

            Section {
                SettingsToggleRow(
                    title: "Extra Time",
                    subtitle: nil,
                    icon: "clock.badge.plus",
                    isOn: $matchViewModel.hasExtraTime
                )
                .listRowInsets(cardRowInsets)
                .listRowBackground(Color.clear)

                SettingsToggleRow(
                    title: "Penalties",
                    subtitle: nil,
                    icon: "soccerball",
                    isOn: $matchViewModel.hasPenalties
                )
                .listRowInsets(cardRowInsets)
                .listRowBackground(Color.clear)
            }

            if matchViewModel.hasExtraTime {
                Section {
                    extraTimeRow
                }
            }

            if matchViewModel.hasPenalties {
                Section {
                    shootoutRow
                }
            }

            Section {
                ThemeCardContainer(role: .positive, minHeight: 80) {
                    Button {
                        startMatch()
                    } label: {
                        HStack(spacing: theme.spacing.m) {
                            Image(systemName: "play.circle.fill")
                                .font(theme.typography.iconAccent)
                                .foregroundStyle(theme.colors.textInverted)

                            Text("Start Match")
                                .font(theme.typography.cardHeadline)
                                .foregroundStyle(theme.colors.textInverted)

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("startMatchButton")
                }
                .listRowInsets(cardRowInsets)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.carousel)
        .scrollContentBackground(.hidden)
        .background(theme.colors.backgroundPrimary)
        .navigationTitle("Match Settings")
    }

    private var durationRow: some View {
        NavigationLink {
            SettingPickerView(
                title: "Duration",
                values: [40, 45, 50],
                selection: $matchViewModel.matchDuration,
                formatter: { "\($0) min" }
            )
        } label: {
            SettingsNavigationRow(
                title: "Duration",
                value: "\(matchViewModel.matchDuration) min",
                icon: "clock",
                valueIdentifier: nil
            )
        }
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)
    }

    private var periodsRow: some View {
        NavigationLink {
            SettingPickerView(
                title: "Periods",
                values: [1, 2, 3, 4],
                selection: $matchViewModel.numberOfPeriods,
                formatter: String.init
            )
        } label: {
            SettingsNavigationRow(
                title: "Periods",
                value: "\(matchViewModel.numberOfPeriods)",
                icon: "square.grid.2x2",
                valueIdentifier: nil
            )
        }
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)
    }

    private var halfTimeRow: some View {
        NavigationLink {
            SettingPickerView(
                title: "Half-time",
                values: [10, 15, 20],
                selection: $matchViewModel.halfTimeLength,
                formatter: { "\($0) min" }
            )
        } label: {
            SettingsNavigationRow(
                title: "HT Length",
                value: "\(matchViewModel.halfTimeLength) min",
                icon: "hourglass.bottomhalf",
                valueIdentifier: nil
            )
        }
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)
    }

    private var extraTimeRow: some View {
        NavigationLink {
            SettingPickerView(
                title: "ET Half Length",
                values: [5, 10, 15, 20, 30],
                selection: $matchViewModel.extraTimeHalfLengthMinutes,
                formatter: { "\($0) min" }
            )
        } label: {
            SettingsNavigationRow(
                title: "ET Half Length",
                value: "\(matchViewModel.extraTimeHalfLengthMinutes) min",
                icon: "stopwatch",
                valueIdentifier: nil
            )
        }
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)
    }

    private var shootoutRow: some View {
        NavigationLink {
            SettingPickerView(
                title: "Shootout Rounds",
                values: [3, 5, 7, 10],
                selection: $matchViewModel.penaltyInitialRounds,
                formatter: { String($0) }
            )
        } label: {
            SettingsNavigationRow(
                title: "Shootout Rounds",
                value: "\(matchViewModel.penaltyInitialRounds)",
                icon: "soccerball",
                valueIdentifier: nil
            )
        }
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)
    }

    private func startMatch() {
        matchViewModel.configureMatch(
            duration: matchViewModel.matchDuration,
            periods: matchViewModel.numberOfPeriods,
            halfTimeLength: matchViewModel.halfTimeLength,
            hasExtraTime: matchViewModel.hasExtraTime,
            hasPenalties: matchViewModel.hasPenalties
        )
        lifecycle.goToKickoffFirst()
        dismiss()
    }

    private var cardRowInsets: EdgeInsets {
        EdgeInsets(
            top: theme.components.listRowVerticalInset,
            leading: 0,
            bottom: theme.components.listRowVerticalInset,
            trailing: 0
        )
    }
}

// View for selecting from saved matches
struct SavedMatchesView: View {
    @Environment(\.theme) private var theme
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(matchViewModel.savedMatches) { match in
                Button {
                    matchViewModel.selectMatch(match)
                    lifecycle.goToKickoffFirst()
                    dismiss()
                } label: {
                    ThemeCardContainer(role: .secondary, minHeight: 72) {
                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            Text("\(match.homeTeam) vs \(match.awayTeam)")
                                .font(theme.typography.cardHeadline)
                                .foregroundStyle(theme.colors.textPrimary)

                            Text("Duration: \(Int(match.duration / 60)) min • Periods: \(match.numberOfPeriods)")
                                .font(theme.typography.cardMeta)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(cardRowInsets)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.carousel)
        .scrollContentBackground(.hidden)
        .background(theme.colors.backgroundPrimary)
        .navigationTitle("Saved Matches")
    }

    private var cardRowInsets: EdgeInsets {
        EdgeInsets(
            top: theme.components.listRowVerticalInset,
            leading: 0,
            bottom: theme.components.listRowVerticalInset,
            trailing: 0
        )
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
    }
}
