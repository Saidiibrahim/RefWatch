import SwiftUI
import RefWatchCore
import WatchKit

struct TeamDetailsView: View {
    enum TeamType {
        case home, away
    }
    
    let teamType: TeamType
    let matchViewModel: MatchViewModel
    let setupViewModel: MatchSetupViewModel
    
    @State private var selectedTeamOfficial: TeamOfficialRole?
    @State private var selectedPlayerNumber: Int?
    @State private var showingPlayerNumberInput = false
    @State private var selectedGoalType: GoalDetails.GoalType?
    @State private var showingYellowCard = false
    @State private var showingRedCard = false
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

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
        .navigationDestination(isPresented: $showingPlayerNumberInput) {
            if let goalType = selectedGoalType {
                PlayerNumberInputView(
                    team: teamType,
                    goalType: goalType,
                    cardType: nil,
                    context: "goal scorer",
                    onComplete: { number in
                        print("DEBUG: Player number entered for goal: #\(number)")
                        recordGoal(type: goalType, playerNumber: number)
                        showingPlayerNumberInput = false
                        selectedGoalType = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingYellowCard) {
            CardEventFlow(
                cardType: .yellow,
                team: teamType,
                matchViewModel: matchViewModel,
                setupViewModel: setupViewModel
            )
        }
        .sheet(isPresented: $showingRedCard) {
            CardEventFlow(
                cardType: .red,
                team: teamType,
                matchViewModel: matchViewModel,
                setupViewModel: setupViewModel
            )
        }
    }
    
    private func recordGoal(type: GoalDetails.GoalType, playerNumber: Int) {
        print("DEBUG: Recording goal - Type: \(type.rawValue), Player: #\(playerNumber), Team: \(teamType)")
        let scoringTeam: TeamSide
        switch type {
        case .regular, .freeKick, .penalty:
            scoringTeam = teamType == .home ? .home : .away
        case .ownGoal:
            // Own goal: credit the OPPOSITE team of the side initiating this flow
            // If entering from home team view, the away team scores, and vice versa.
            scoringTeam = teamType == .home ? .away : .home
        }
        matchViewModel.recordGoal(
            team: scoringTeam,
            goalType: type,
            playerNumber: playerNumber
        )
        print("DEBUG: Goal recording completed successfully using new system")
        print("DEBUG: Navigating to middle screen...")
        setupViewModel.setSelectedTab(1)
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
            AdaptiveEventGridItem(icon: "square.fill", color: .yellow, label: "Yellow") {
                WKInterfaceDevice.current().play(haptic(for: "square.fill"))
                showingYellowCard = true
            },
            AdaptiveEventGridItem(icon: "square.fill", color: .red, label: "Red") {
                WKInterfaceDevice.current().play(haptic(for: "square.fill"))
                showingRedCard = true
            },
            AdaptiveEventGridItem(icon: "arrow.up.arrow.down", color: .blue, label: "Sub", onTap: {
                WKInterfaceDevice.current().play(haptic(for: "arrow.up.arrow.down"))
            }) {
                SubstitutionFlow(
                    team: teamType,
                    matchViewModel: matchViewModel,
                    setupViewModel: setupViewModel
                )
            },
            AdaptiveEventGridItem(icon: "soccerball", color: .green, label: "Goal", onTap: {
                WKInterfaceDevice.current().play(haptic(for: "soccerball"))
            }) {
                GoalTypeSelectionView(
                    team: teamType,
                    teamDisplayName: teamDisplayName
                ) { goalType in
                    selectedGoalType = goalType
                    showingPlayerNumberInput = true
                }
            }
        ]
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
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        
}

#Preview("Team Details – Ultra") {
    let matchViewModel = MatchViewModel(haptics: WatchHaptics())
    let setupViewModel = MatchSetupViewModel(matchViewModel: matchViewModel)

    return TeamDetailsView(teamType: .away, matchViewModel: matchViewModel, setupViewModel: setupViewModel)
        .watchLayoutScale(WatchLayoutScale(category: .expanded))
        
}
