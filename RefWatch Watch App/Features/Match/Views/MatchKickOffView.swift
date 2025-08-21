// MatchKickOffView.swift
// Description: Screen shown before match/period start to select kicking team

import SwiftUI

struct MatchKickOffView: View {
    let matchViewModel: MatchViewModel
    @State private var selectedTeam: Team?
    @Environment(\.dismiss) private var dismiss
    
    enum Team {
        case home, away
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with time and kick off text (right-aligned)
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Text(formattedCurrentTime)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text("Kick off")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            
            // Team selection boxes (horizontal layout)
            HStack(spacing: 12) {
                SimpleTeamBox(
                    teamName: "HOM",
                    score: matchViewModel.currentMatch?.homeScore ?? 0,
                    isSelected: selectedTeam == .home,
                    action: { selectedTeam = .home }
                )
                
                SimpleTeamBox(
                    teamName: "AWA", 
                    score: matchViewModel.currentMatch?.awayScore ?? 0,
                    isSelected: selectedTeam == .away,
                    action: { selectedTeam = .away }
                )
            }
            .padding(.horizontal)
            
            // Duration button
            Button(action: { dismiss() }) {
                CompactButton(
                    title: "\(matchViewModel.matchDuration/2):00 ▼",
                    style: .secondary
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Start button (simple green circle with checkmark)
            NavigationLink(
                destination: MatchSetupView(matchViewModel: matchViewModel)
                    .navigationBarBackButtonHidden()
            ) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(selectedTeam != nil ? Color.green : Color.gray)
                    )
            }
            .buttonStyle(PlainButtonStyle()) // Removes default grey background
            .disabled(selectedTeam == nil)
            .simultaneousGesture(TapGesture().onEnded {
                print("DEBUG: Navigation tap gesture triggered")
                if let team = selectedTeam {
                    // Configure the match first
                    matchViewModel.configureMatch(
                        duration: matchViewModel.matchDuration,
                        periods: matchViewModel.numberOfPeriods,
                        halfTimeLength: matchViewModel.halfTimeLength,
                        hasExtraTime: matchViewModel.hasExtraTime,
                        hasPenalties: matchViewModel.hasPenalties
                    )
                    // Set the kicking team
                    matchViewModel.setKickingTeam(team == .home)
                    // Start the match immediately to skip confirmation step
                    matchViewModel.startMatch()
                }
            })
            .padding(.bottom, 12)
        }
        .navigationBarBackButtonHidden()
    }
    
    // Computed property for current time
    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date())
    }
}

// Simple team box component matching target design
private struct SimpleTeamBox: View {
    let teamName: String
    let score: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(teamName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(score)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.7))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 