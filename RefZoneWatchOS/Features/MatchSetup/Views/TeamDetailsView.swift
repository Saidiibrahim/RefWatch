import SwiftUI
import RefWatchCore
import WatchKit

struct TeamDetailsView: View {
    enum TeamType: Hashable {
        case home, away
    }
    
    let teamType: TeamType
    let matchViewModel: MatchViewModel
    let setupViewModel: MatchSetupViewModel
    let onGoalTypeSelected: (GoalDetails.GoalType) -> Void
    
    init(
        teamType: TeamType,
        matchViewModel: MatchViewModel,
        setupViewModel: MatchSetupViewModel,
        onGoalTypeSelected: @escaping (GoalDetails.GoalType) -> Void = { _ in }
    ) {
        self.teamType = teamType
        self.matchViewModel = matchViewModel
        self.setupViewModel = setupViewModel
        self.onGoalTypeSelected = onGoalTypeSelected
    }

    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    @Environment(SettingsViewModel.self) private var settingsViewModel

    var body: some View {
        VStack(spacing: theme.spacing.m) {
            header

            AdaptiveEventGrid(items: eventGridItems)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.top, theme.spacing.s)
        .padding(.bottom, layout.safeAreaBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    }

    private var header: some View {
        Text(teamDisplayName)
            .font(theme.typography.label.weight(.semibold))
            .foregroundStyle(theme.colors.textSecondary)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, theme.spacing.xs)
            .accessibilityLabel(teamDisplayNameAccessibility)
    }

    private var eventGridItems: [AdaptiveEventGridItem] {
        [
            AdaptiveEventGridItem(id: "yellow-card", icon: "square.fill", color: .yellow, label: "Yellow", onTap: {
                WKInterfaceDevice.current().play(haptic(for: "square.fill"))
            }) {
                CardEventFlow(
                    cardType: .yellow,
                    team: teamType,
                    matchViewModel: matchViewModel,
                    setupViewModel: setupViewModel
                )
            },
            AdaptiveEventGridItem(id: "red-card", icon: "square.fill", color: .red, label: "Red", onTap: {
                WKInterfaceDevice.current().play(haptic(for: "square.fill"))
            }) {
                CardEventFlow(
                    cardType: .red,
                    team: teamType,
                    matchViewModel: matchViewModel,
                    setupViewModel: setupViewModel
                )
            },
            AdaptiveEventGridItem(id: "substitution", icon: "arrow.up.arrow.down", color: .blue, label: "Sub", onTap: {
                WKInterfaceDevice.current().play(haptic(for: "arrow.up.arrow.down"))
            }) {
                SubstitutionFlow(
                    team: teamType,
                    matchViewModel: matchViewModel,
                    setupViewModel: setupViewModel,
                    initialStep: initialSubstitutionStep
                )
            },
            AdaptiveEventGridItem(id: "goal", icon: "soccerball", color: .green, label: "Goal", onTap: {
                WKInterfaceDevice.current().play(haptic(for: "soccerball"))
            }) {
                GoalTypeSelectionView(
                    team: teamType,
                    teamDisplayName: teamDisplayName
                ) { goalType in
                    onGoalTypeSelected(goalType)
                }
            }
        ]
    }

    private var initialSubstitutionStep: SubstitutionFlow.SubstitutionStep {
        settingsViewModel.settings.substitutionOrderPlayerOffFirst ? .playerOff : .playerOn
    }

    private func haptic(for icon: String) -> WKHapticType {
        switch icon {
        case "square.fill":
            return .notification
        case "arrow.up.arrow.down":
            return .click
        case "soccerball":
            return .click
        default:
            return .notification
        }
    }

    private var teamDisplayName: String {
        let rawName = teamType == .home ? matchViewModel.homeTeamDisplayName : matchViewModel.awayTeamDisplayName
        if rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return teamType == .home ? "Home" : "Away"
        }
        return rawName
    }

    private var teamDisplayNameAccessibility: String {
        let role = teamType == .home ? "home team" : "away team"
        return "\(teamDisplayName), \(role)"
    }
}

#Preview("Team Details – 41mm") {
    let matchViewModel = MatchViewModel(haptics: WatchHaptics())
    let setupViewModel = MatchSetupViewModel(matchViewModel: matchViewModel)

    return TeamDetailsView(teamType: .home, matchViewModel: matchViewModel, setupViewModel: setupViewModel)
        .environment(SettingsViewModel())
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        
}

#Preview("Team Details – Ultra") {
    let matchViewModel = MatchViewModel(haptics: WatchHaptics())
    let setupViewModel = MatchSetupViewModel(matchViewModel: matchViewModel)

    return TeamDetailsView(teamType: .away, matchViewModel: matchViewModel, setupViewModel: setupViewModel)
        .environment(SettingsViewModel())
        .watchLayoutScale(WatchLayoutScale(category: .expanded))
        
}
