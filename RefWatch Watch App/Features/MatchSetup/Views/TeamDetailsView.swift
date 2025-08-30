import SwiftUI
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
    
    var body: some View {
        VStack {
            Text(teamType == .home ? "HOM" : "AWA")
                .font(.title2)
                .bold()
                .padding(.bottom, 8)
            
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    NavigationLink {
                        CardEventFlow(
                            cardType: .yellow,
                            team: teamType,
                            matchViewModel: matchViewModel,
                            setupViewModel: setupViewModel
                        )
                    } label: {
                        EventButtonView(
                            icon: "square.fill",
                            color: .yellow,
                            label: "Yellow",
                            isNavigationLabel: true
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            WKInterfaceDevice.current().play(.notification)
                        }
                    )
                    
                    NavigationLink {
                        CardEventFlow(
                            cardType: .red,
                            team: teamType,
                            matchViewModel: matchViewModel,
                            setupViewModel: setupViewModel
                        )
                    } label: {
                        EventButtonView(
                            icon: "square.fill",
                            color: .red,
                            label: "Red",
                            isNavigationLabel: true
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            WKInterfaceDevice.current().play(.notification)
                        }
                    )
                }
                
                HStack(spacing: 20) {
                    NavigationLink {
                        SubstitutionFlow(
                            team: teamType,
                            matchViewModel: matchViewModel,
                            setupViewModel: setupViewModel
                        )
                    } label: {
                        EventButtonView(
                            icon: "arrow.up.arrow.down",
                            color: .blue,
                            label: "Sub",
                            isNavigationLabel: true
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            WKInterfaceDevice.current().play(.click)
                        }
                    )
                    
                    NavigationLink {
                        GoalTypeSelectionView(team: teamType) { goalType in
                            print("DEBUG: Goal type received in TeamDetailsView: \(goalType.rawValue) for team: \(teamType)")
                            selectedGoalType = goalType
                            showingPlayerNumberInput = true
                        }
                    } label: {
                        EventButtonView(
                            icon: "soccerball",
                            color: .green,
                            label: "Goal",
                            isNavigationLabel: true
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            WKInterfaceDevice.current().play(.click)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationDestination(isPresented: $showingPlayerNumberInput) {
            if let goalType = selectedGoalType {
                PlayerNumberInputView(
                    team: teamType,
                    goalType: goalType,
                    cardType: nil,
                    onComplete: { number in
                        print("DEBUG: Player number entered for goal: #\(number)")
                        recordGoal(type: goalType, playerNumber: number)
                        showingPlayerNumberInput = false
                        selectedGoalType = nil
                    }
                )
            }
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
            scoringTeam = teamType == .away ? .home : .away
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
}
