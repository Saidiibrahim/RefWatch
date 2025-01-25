import SwiftUI

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
                            action: {}
                        )
                    }
                    
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
                            action: {}
                        )
                    }
                }
                
                HStack(spacing: 20) {
                    EventButtonView(
                        icon: "arrow.up.arrow.down",
                        color: .blue,
                        label: "Sub"
                    ) {
                        addEvent(.substitution)
                    }
                    
                    NavigationLink {
                        GoalTypeSelectionView(team: teamType) { goalType in
                            selectedGoalType = goalType
                            showingPlayerNumberInput = true
                        }
                    } label: {
                        EventButtonView(
                            icon: "soccerball",
                            color: .white,
                            label: "Goal"
                        ) { }
                    }
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
                        recordGoal(type: goalType, playerNumber: number)
                    }
                )
            }
        }
    }
    
    private func recordGoal(type: GoalTypeSelectionView.GoalType, playerNumber: Int) {
        switch type {
        case .goal, .freeKick, .penalty:
            matchViewModel.updateScore(isHome: teamType == .home)
        case .ownGoal:
            matchViewModel.updateScore(isHome: teamType == .away)
        }
        
        let event = MatchEvent.goal
        matchViewModel.addEvent(event, for: teamType == .home ? .home : .away)
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
        
        matchViewModel.addEvent(type, for: teamType == .home ? .home : .away)
        matchViewModel.addCard(
            isHome: teamType == .home,
            isYellow: type == .yellow
        )
        
        // Reset all states
        currentCardType = nil
        selectedPlayerNumber = nil
        selectedTeamOfficial = nil
        isTeamOfficial = false
        showingCardReasonSelection = false
        
        // Switch to tab 1 (middle screen) and log success
        print("DEBUG: Successfully recorded card, navigating to middle screen...")
        setupViewModel.setSelectedTab(1)
    }
} 