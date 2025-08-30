// SubstitutionFlow.swift
// Description: View for handling player substitution process

import SwiftUI

struct SubstitutionFlow: View {
    let team: TeamDetailsView.TeamType
    let matchViewModel: MatchViewModel
    let setupViewModel: MatchSetupViewModel
    
    @State private var step: SubstitutionStep = .playerOff
    @State private var playerOffNumber: Int?
    @State private var playerOnNumber: Int?
    @Environment(\.dismiss) private var dismiss
    
    enum SubstitutionStep {
        case playerOff
        case playerOn
        case confirmation
    }
    
    var body: some View {
        NavigationStack {
            switch step {
            case .playerOff:
                PlayerNumberInputView(
                    team: team,
                    goalType: nil,
                    cardType: nil,
                    onComplete: { number in
                        playerOffNumber = number
                        step = .playerOn
                    }
                )
                .navigationTitle("\(team == .home ? "HOM" : "AWA") - Player Off")
                
            case .playerOn:
                PlayerNumberInputView(
                    team: team,
                    goalType: nil,
                    cardType: nil,
                    onComplete: { number in
                        playerOnNumber = number
                        step = .confirmation
                    }
                )
                .navigationTitle("\(team == .home ? "HOM" : "AWA") - Player On")
                .navigationBarBackButtonHidden(false)
                
            case .confirmation:
                confirmationView
                    .navigationTitle("Confirm Substitution")
                    .navigationBarBackButtonHidden(false)
            }
        }
    }
    
    private var confirmationView: some View {
        VStack(spacing: 20) {
            Text("Substitution")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Player Off:")
                        .font(.body)
                    Spacer()
                    Text("#\(playerOffNumber ?? 0)")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Player On:")
                        .font(.body)
                    Spacer()
                    Text("#\(playerOnNumber ?? 0)")
                        .font(.title2)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            
            Spacer()
            
            Button("Confirm Substitution") {
                recordSubstitution()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func recordSubstitution() {
        guard let offNumber = playerOffNumber,
              let onNumber = playerOnNumber else { return }
        
        print("DEBUG: Recording substitution - Off: #\(offNumber), On: #\(onNumber), Team: \(team)")
        
        // Map team to new enum
        let teamSide: TeamSide = team == .home ? .home : .away
        
        // Record substitution using new comprehensive system
        matchViewModel.recordSubstitution(
            team: teamSide,
            playerOut: offNumber,
            playerIn: onNumber
        )
        
        print("DEBUG: Substitution recorded successfully using new system")
        
        // Navigate back to middle screen
        setupViewModel.setSelectedTab(1)
        
        // Dismiss the entire flow
        dismiss()
    }
}