// MatchSetupView.swift
// Implements the three-screen swipeable layout:
// Left: Home team details
// Middle: Match start screen
// Right: Away team details

import SwiftUI

struct MatchSetupView: View {
    @State private var viewModel: MatchSetupViewModel
    @Environment(\.dismiss) private var dismiss // Dismiss this pushed view back to StartMatchScreen
    @Environment(\.presentationMode) var presentationMode
    let onExitToRoot: () -> Void // Callback to pop to ContentView
    
    init(matchViewModel: MatchViewModel, onExitToRoot: @escaping () -> Void) {
        _viewModel = State(initialValue: MatchSetupViewModel(matchViewModel: matchViewModel))
        self.onExitToRoot = onExitToRoot
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
            TimerView(
                model: viewModel.matchViewModel,
                onReturnHome: {
                    // Navigate back to StartMatchScreen
                    presentationMode.wrappedValue.dismiss()
                    onExitToRoot()
                }
            )
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