import SwiftUI
import WatchKit

struct TeamDetailsView: View {
    enum TeamType {
        case home, away
    }
    
    let teamType: TeamType
    let matchViewModel: MatchViewModel
    let setupViewModel: MatchSetupViewModel
    
    @State private var showingCardRecipientSelection = false
    @State private var showingTeamOfficialSelection = false
    @State private var showingCardReasonSelection = false
    @State private var currentCardType: MatchEvent?
    @State private var isTeamOfficial = false
    @State private var selectedTeamOfficial: TeamOfficialRole?
    @State private var selectedPlayerNumber: Int?
    @State private var showingPlayerNumberInput = false
    @State private var selectedGoalType: GoalTypeSelectionView.GoalType?
    
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
                            print("DEBUG: Goal type received in TeamDetailsView: \(goalType.label) for team: \(teamType)")
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
        .navigationDestination(isPresented: $showingCardRecipientSelection) {
            if let cardType = currentCardType {
                CardRecipientSelectionView(
                    team: teamType,
                    cardType: cardType,
                    onComplete: { recipient in
                        showingCardRecipientSelection = false
                        if recipient == .player {
                            showingPlayerNumberInput = true
                        } else {
                            isTeamOfficial = true
                            showingTeamOfficialSelection = true
                        }
                    }
                )
            }
        }
        .navigationDestination(isPresented: $showingTeamOfficialSelection) {
            TeamOfficialSelectionView(team: teamType) { role in
                selectedTeamOfficial = role
                showingTeamOfficialSelection = false
                showingCardReasonSelection = true
            }
        }
        .navigationDestination(isPresented: $showingCardReasonSelection) {
            if let cardType = currentCardType {
                NavigationStack {
                    CardReasonSelectionView(
                        cardType: cardType,
                        isTeamOfficial: isTeamOfficial
                    ) { reason in
                        recordCard(
                            type: cardType,
                            reason: reason,
                            playerNumber: selectedPlayerNumber,
                            officialRole: selectedTeamOfficial
                        )
                        showingCardReasonSelection = false
                        setupViewModel.setSelectedTab(1)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingPlayerNumberInput) {
            if let cardType = currentCardType {
                PlayerNumberInputView(
                    team: teamType,
                    goalType: nil,
                    cardType: cardType,
                    onComplete: { number in
                        selectedPlayerNumber = number
                        showingPlayerNumberInput = false
                        showingCardReasonSelection = true
                        print("DEBUG: Player number selected: \(number), showing card reason selection")
                    }
                )
            } else if let goalType = selectedGoalType {
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
    
    private func recordGoal(type: GoalTypeSelectionView.GoalType, playerNumber: Int) {
        print("DEBUG: Recording goal - Type: \(type.label), Player: #\(playerNumber), Team: \(teamType)")
        
        // Map goal type to new enum
        let goalType: GoalDetails.GoalType
        let scoringTeam: TeamSide
        
        switch type {
        case .goal:
            goalType = .regular
            scoringTeam = teamType == .home ? .home : .away
        case .ownGoal:
            goalType = .ownGoal
            scoringTeam = teamType == .away ? .home : .away // Own goal goes to opposite team
        case .freeKick:
            goalType = .freeKick
            scoringTeam = teamType == .home ? .home : .away
        case .penalty:
            goalType = .penalty
            scoringTeam = teamType == .home ? .home : .away
        }
        
        // Record goal using new comprehensive system
        matchViewModel.recordGoal(
            team: scoringTeam,
            goalType: goalType,
            playerNumber: playerNumber
        )
        
        print("DEBUG: Goal recording completed successfully using new system")
        
        // Navigate to middle screen after recording goal
        print("DEBUG: Navigating to middle screen...")
        setupViewModel.setSelectedTab(1)
    }
    
    private func addEvent(_ event: MatchEvent) {
        matchViewModel.addEvent(event, for: teamType == .home ? .home : .away)
    }
    
    private func recordCard(
        type: MatchEvent,
        reason: String,
        playerNumber: Int?,
        officialRole: TeamOfficialRole?
    ) {
        print("DEBUG: Recording card - Type: \(type), Reason: \(reason), Player: \(String(describing: playerNumber)), Official: \(String(describing: officialRole))")
        
        // Map card type and recipient type
        let cardType: CardDetails.CardType = type == .yellow ? .yellow : .red
        let recipientType: CardRecipientType = isTeamOfficial ? .teamOfficial : .player
        let team: TeamSide = teamType == .home ? .home : .away
        
        // Record card using new comprehensive system
        matchViewModel.recordCard(
            team: team,
            cardType: cardType,
            recipientType: recipientType,
            playerNumber: playerNumber,
            officialRole: officialRole,
            reason: reason
        )
        
        // Reset all states
        currentCardType = nil
        selectedPlayerNumber = nil
        selectedTeamOfficial = nil
        isTeamOfficial = false
        showingCardReasonSelection = false
        
        // Switch to tab 1 (middle screen) and log success
        print("DEBUG: Successfully recorded card using new system, navigating to middle screen...")
        setupViewModel.setSelectedTab(1)
    }
} 