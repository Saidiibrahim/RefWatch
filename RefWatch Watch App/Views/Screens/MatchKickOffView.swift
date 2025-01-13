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
        VStack(spacing: 20) {
            // Time display
            HStack {
                Spacer()
                Text("Kick off")
                    .font(.system(size: 16))
            }
            .padding(.horizontal)
            
            // Team selection
            HStack(spacing: 0) {
                // Home team
                TeamButton(
                    name: matchViewModel.homeTeam,
                    isSelected: selectedTeam == .home,
                    action: { selectedTeam = .home }
                )
                
                // Away team
                TeamButton(
                    name: matchViewModel.awayTeam,
                    isSelected: selectedTeam == .away,
                    action: { selectedTeam = .away }
                )
            }
            .padding(.vertical)
            
            // Duration button
            Button(action: { dismiss() }) {
                Text("\(matchViewModel.matchDuration/2):00 ▼")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding()
            
            Spacer()
            
            // Start button
            NavigationLink(
                destination: MatchSetupView(matchViewModel: matchViewModel)
                    .navigationBarBackButtonHidden()
            ) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            .disabled(selectedTeam == nil)
            .opacity(selectedTeam == nil ? 0.5 : 1)
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
                    // Then set the kicking team
                    matchViewModel.setKickingTeam(team == .home)
                }
            })
        }
        .navigationBarBackButtonHidden()
    }
}

private struct TeamButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.yellow : Color.gray.opacity(0.3))
                )
        }
        .padding(.horizontal, 4)
    }
} 