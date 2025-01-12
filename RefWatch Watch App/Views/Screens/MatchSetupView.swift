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
        VStack(spacing: 16) {
            Text(teamType == .home ? "HOM" : "AWA")
                .font(.title2)
                .bold()
            
            // Match events buttons
            VStack(spacing: 12) {
                Button(action: { addEvent(.yellow) }) {
                    EventButton(icon: "square.fill", color: .yellow, label: "Yellow")
                }
                
                Button(action: { addEvent(.red) }) {
                    EventButton(icon: "square.fill", color: .red, label: "Red")
                }
                
                Button(action: { addEvent(.substitution) }) {
                    EventButton(icon: "arrow.up.arrow.down", color: .blue, label: "Sub")
                }
                
                Button(action: { addEvent(.goal) }) {
                    EventButton(icon: "soccerball", color: .white, label: "Goal")
                }
            }
        }
        .padding()
    }
    
    private func addEvent(_ event: MatchEvent) {
        matchViewModel.addEvent(event, for: teamType == .home ? .home : .away)
    }
}

// Reusable button style for match events
struct EventButton: View {
    let icon: String
    let color: Color
    let label: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

// Match event types
enum MatchEvent {
    case yellow, red, substitution, goal
}