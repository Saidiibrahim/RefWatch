// New file: GoalTypeSelectionView.swift
// Description: View for selecting the type of goal scored

import SwiftUI

struct GoalTypeSelectionView: View {
    let team: TeamDetailsView.TeamType
    let onSelect: (GoalType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    enum GoalType {
        case goal
        case ownGoal
        case freeKick
        case penalty
        
        var label: String {
            switch self {
            case .goal: return "Goal"
            case .ownGoal: return "Own goal"
            case .freeKick: return "Free Kick"
            case .penalty: return "Penalty"
            }
        }
    }
    
    var body: some View {
        List {
            ForEach([GoalType.goal, .ownGoal, .freeKick, .penalty], id: \.self) { type in
                Button(action: { 
                    print("DEBUG: Goal type selected: \(type.label)")
                    onSelect(type) 
                }) {
                    Text(type.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(team == .home ? "HOM" : "AWA")
        .listStyle(.carousel)
    }
} 