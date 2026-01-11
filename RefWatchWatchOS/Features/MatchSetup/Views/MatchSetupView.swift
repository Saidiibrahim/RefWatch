// MatchSetupView.swift
// Implements the three-screen swipeable layout:
// Left: Home team details
// Middle: Match start screen
// Right: Away team details

import SwiftUI
import RefWatchCore

struct MatchSetupView: View {
    @State private var viewModel: MatchSetupViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var goalInputContext: GoalInputContext?
    @State private var cardEventContext: CardEventContext?
    @State private var substitutionContext: SubstitutionContext?
    @Environment(SettingsViewModel.self) private var settingsViewModel

    init(matchViewModel: MatchViewModel, lifecycle: MatchLifecycleCoordinator) {
        _viewModel = State(initialValue: MatchSetupViewModel(matchViewModel: matchViewModel))
        self.lifecycle = lifecycle
    }

    var body: some View {
        TabView(selection: .init(
            get: { viewModel.selectedTab },
            set: { viewModel.setSelectedTab($0) }
        )) {
            // Home Team Details
            TeamDetailsView(
                teamType: .home,
                matchViewModel: viewModel.matchViewModel,
                onGoalTypeSelected: { goalType in
                    goalInputContext = GoalInputContext(team: .home, goalType: goalType)
                },
                onCardSelected: { cardType in
                    cardEventContext = CardEventContext(team: .home, cardType: cardType)
                },
                onSubstitutionSelected: {
                    substitutionContext = SubstitutionContext(
                        team: .home,
                        initialStep: settingsViewModel.settings.substitutionOrderPlayerOffFirst ? .playerOff : .playerOn
                    )
                }
            )
            .tag(0)

            // Timer View (Middle)
            TimerView(
                model: viewModel.matchViewModel,
                lifecycle: lifecycle
            )
                .tag(1)

            // Away Team Details
            TeamDetailsView(
                teamType: .away,
                matchViewModel: viewModel.matchViewModel,
                onGoalTypeSelected: { goalType in
                    goalInputContext = GoalInputContext(team: .away, goalType: goalType)
                },
                onCardSelected: { cardType in
                    cardEventContext = CardEventContext(team: .away, cardType: cardType)
                },
                onSubstitutionSelected: {
                    substitutionContext = SubstitutionContext(
                        team: .away,
                        initialStep: settingsViewModel.settings.substitutionOrderPlayerOffFirst ? .playerOff : .playerOn
                    )
                }
            )
            .tag(2)
        }
        .tabViewStyle(.page)
        .navigationDestination(item: $goalInputContext) { context in
            PlayerNumberInputView(
                team: context.team,
                goalType: context.goalType,
                cardType: nil,
                context: "goal scorer",
                onComplete: { number in
                    recordGoal(teamType: context.team, goalType: context.goalType, playerNumber: number)
                    goalInputContext = nil
                }
            )
        }
        .navigationDestination(item: $cardEventContext) { context in
            CardEventFlow(
                cardType: context.cardType,
                team: context.team,
                matchViewModel: viewModel.matchViewModel,
                onComplete: {
                    cardEventContext = nil
                    viewModel.setSelectedTab(1)
                }
            )
        }
        .navigationDestination(item: $substitutionContext) { context in
            SubstitutionFlow(
                team: context.team,
                matchViewModel: viewModel.matchViewModel,
                initialStep: context.initialStep,
                onComplete: {
                    substitutionContext = nil
                    viewModel.setSelectedTab(1)
                }
            )
        }
    }

    private func recordGoal(teamType: TeamDetailsView.TeamType, goalType: GoalDetails.GoalType, playerNumber: Int) {
        print("DEBUG: Recording goal - Type: \(goalType.rawValue), Player: #\(playerNumber), Team: \(teamType)")
        let scoringTeam: TeamSide
        switch goalType {
        case .regular, .freeKick, .penalty:
            scoringTeam = teamType == .home ? .home : .away
        case .ownGoal:
            // Own goal: credit the opposite team of the side initiating this flow
            scoringTeam = teamType == .home ? .away : .home
        }
        viewModel.matchViewModel.recordGoal(
            team: scoringTeam,
            goalType: goalType,
            playerNumber: playerNumber
        )
        print("DEBUG: Goal recording completed successfully using new system")
        print("DEBUG: Navigating to middle screen...")
        viewModel.setSelectedTab(1)
    }
}

// MARK: - Navigation Helpers

private struct GoalInputContext: Identifiable, Hashable {
    let id: String
    let team: TeamDetailsView.TeamType
    let goalType: GoalDetails.GoalType

    init(team: TeamDetailsView.TeamType, goalType: GoalDetails.GoalType) {
        self.team = team
        self.goalType = goalType
        let teamId = team == .home ? "home" : "away"
        self.id = "\(teamId)-\(goalType.rawValue)"
    }
}

private struct CardEventContext: Identifiable, Hashable {
    let id = UUID()
    let team: TeamDetailsView.TeamType
    let cardType: CardDetails.CardType
}

private struct SubstitutionContext: Identifiable, Hashable {
    let id = UUID()
    let team: TeamDetailsView.TeamType
    let initialStep: SubstitutionFlow.SubstitutionStep
}
