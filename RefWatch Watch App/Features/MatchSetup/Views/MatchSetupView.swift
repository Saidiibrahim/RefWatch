// MatchSetupView.swift
// Implements the three-screen swipeable layout:
// Left: Home team details
// Middle: Match start screen
// Right: Away team details

import SwiftUI

struct MatchSetupView: View {
    @State private var viewModel: MatchSetupViewModel
    
    init(matchViewModel: MatchViewModel) {
        _viewModel = State(initialValue: MatchSetupViewModel(matchViewModel: matchViewModel))
    }
    
    var body: some View {
        TabView(selection: .init(
            get: { viewModel.selectedTab },
            set: { viewModel.setSelectedTab($0) }
        )) {
            // Home Team Details
            TeamDetailsView(
                teamType: .home,
                matchViewModel: viewModel.matchViewModel,
                setupViewModel: viewModel
            )
            .tag(0)
            
            // Timer View (Middle)
            TimerView(model: viewModel.matchViewModel)
                .tag(1)
            
            // Away Team Details
            TeamDetailsView(
                teamType: .away,
                matchViewModel: viewModel.matchViewModel,
                setupViewModel: viewModel
            )
            .tag(2)
        }
        .tabViewStyle(.page)
    }
}