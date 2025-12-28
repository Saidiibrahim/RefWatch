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
                setupViewModel: viewModel,
                onGoalTypeSelected: { goalType in
                    goalInputContext = GoalInputContext(team: .home, goalType: goalType)
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
                setupViewModel: viewModel,
                onGoalTypeSelected: { goalType in
                    goalInputContext = GoalInputContext(team: .away, goalType: goalType)
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
