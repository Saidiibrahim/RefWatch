// New file: GoalTypeSelectionView.swift
// Description: View for selecting the type of goal scored

import SwiftUI
import RefWatchCore

struct GoalTypeSelectionView: View {
    let team: TeamDetailsView.TeamType
    let onSelect: (GoalDetails.GoalType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let allTypes: [GoalDetails.GoalType] = [.regular, .ownGoal, .freeKick, .penalty]
    
    private func label(for type: GoalDetails.GoalType) -> String {
        switch type {
        case .regular: return "Goal"
        case .ownGoal: return "Own goal"
        case .freeKick: return "Free Kick"
        case .penalty: return "Penalty"
        }
    }
    
    var body: some View {
        List {
            ForEach(allTypes, id: \.self) { type in
                Button(action: { 
                    print("DEBUG: Goal type selected: \(label(for: type))")
                    onSelect(type) 
                }) {
                    Text(label(for: type))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(team == .home ? "HOM" : "AWA")
        .listStyle(.carousel)
    }
} 
