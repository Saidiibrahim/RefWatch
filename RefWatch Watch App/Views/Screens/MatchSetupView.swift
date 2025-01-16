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
                        addEvent(.yellow)
                    }
                    
                    EventButtonView(
                        icon: "square.fill",
                        color: .red,
                        label: "Red"
                    ) {
                        addEvent(.red)
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
                    
                    EventButtonView(
                        icon: "soccerball",
                        color: .white,
                        label: "Goal"
                    ) {
                        addEvent(.goal)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func addEvent(_ event: MatchEvent) {
        matchViewModel.addEvent(event, for: teamType == .home ? .home : .away)
    }
}

// Match event types
enum MatchEvent {
    case yellow, red, substitution, goal
}