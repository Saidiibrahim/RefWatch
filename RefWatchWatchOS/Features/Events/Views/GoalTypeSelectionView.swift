//
//  GoalTypeSelectionView.swift
//  RefWatchWatchOS
//
//  Description: View for selecting the type of goal scored
//  Rule Applied: Code Structure - abstracted selection list to reusable component
//

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
        // Use the new reusable SelectionListView component with custom formatter
        SelectionListView(
            title: team == .home ? "HOM" : "AWA",
            options: allTypes,
            formatter: label(for:),
            useCarouselStyle: true
        ) { type in
            print("DEBUG: Goal type selected: \(label(for: type))")
            onSelect(type)
        }
    }
} 
