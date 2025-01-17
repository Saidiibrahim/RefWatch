// MatchSetupView.swift
// Implements the three-screen swipeable layout:
// Left: Home team details
// Middle: Match start screen
// Right: Away team details

import SwiftUI

struct MatchSetupView: View {
    let matchViewModel: MatchViewModel
    @State private var selectedTab = 1 // Start in the middle
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Team Details
            TeamDetailsView(teamType: .home, matchViewModel: matchViewModel)
                .tag(0)
            
            // Timer View (Middle)
            TimerView(model: matchViewModel)
                .tag(1)
            
            // Away Team Details
            TeamDetailsView(teamType: .away, matchViewModel: matchViewModel)
                .tag(2)
        }
        .tabViewStyle(.page)
        .onAppear {
            // Start the match when this view appears
            matchViewModel.startMatch()
        }
    }
}

// Middle screen with match details and start button
struct StartMatchDetailsView: View {
    let matchViewModel: MatchViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("\(matchViewModel.homeTeam) vs \(matchViewModel.awayTeam)")
                .font(.title3)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration: \(matchViewModel.matchDuration) min")
                Text("Periods: \(matchViewModel.numberOfPeriods)")
                Text("Half-time: \(matchViewModel.halfTimeLength) min")
                if matchViewModel.hasExtraTime {
                    Text("Extra Time: Yes")
                }
                if matchViewModel.hasPenalties {
                    Text("Penalties: Yes")
                }
            }
            .font(.footnote)
            
            Spacer()
            
            // Start match button
            NavigationLink(destination: TimerView(model: matchViewModel)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
            }
            .simultaneousGesture(TapGesture().onEnded {
                matchViewModel.startMatch()
            })
        }
        .padding()
    }
}

// Team details screen for recording match events
struct TeamDetailsView: View {
    enum TeamType {
        case home, away
    }
    
    let teamType: TeamType
    let matchViewModel: MatchViewModel
    
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
            
            // 2x2 grid layout with more spacing
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    EventButtonView(
                        icon: "square.fill",
                        color: .yellow,
                        label: "Yellow"
                    ) {
                        currentCardType = .yellow
                        showingCardRecipientSelection = true
                    }
                    
                    EventButtonView(
                        icon: "square.fill",
                        color: .red,
                        label: "Red"
                    ) {
                        currentCardType = .red
                        showingCardRecipientSelection = true
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
                    onSelectPlayer: {
                        showingCardRecipientSelection = false
                        showingPlayerNumberInput = true
                    },
                    onSelectOfficial: {
                        isTeamOfficial = true
                        showingCardRecipientSelection = false
                        showingTeamOfficialSelection = true
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
                }
            }
        }
        .navigationDestination(isPresented: $showingPlayerNumberInput) {
            if currentCardType != nil {
                // For card flow
                PlayerNumberInputView(
                    team: teamType,
                    goalType: nil,
                    cardType: currentCardType,
                    onComplete: { number in
                        selectedPlayerNumber = number
                        showingPlayerNumberInput = false
                        showingCardReasonSelection = true
                    }
                )
            } else if let goalType = selectedGoalType {
                // For goal flow
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
        // Update match statistics based on goal type
        switch type {
        case .goal, .freeKick, .penalty:
            matchViewModel.updateScore(isHome: teamType == .home)
        case .ownGoal:
            matchViewModel.updateScore(isHome: teamType == .away)
        }
        
        // Add the event with additional details
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
        // Add event details
        matchViewModel.addEvent(type, for: teamType == .home ? .home : .away)
        
        // Reset all state
        currentCardType = nil
        selectedPlayerNumber = nil
        selectedTeamOfficial = nil
        isTeamOfficial = false
        showingCardReasonSelection = false
    }
}

// Match event types
enum MatchEvent {
    case yellow, red, substitution, goal
}