//
//  StartMatchScreen.swift
//  RefereeAssistant
//
//  Description: Orchestrates the Start Match flow by composing reusable
//  components for selecting an existing match or creating a new one.
//  This view wires environment state and lifecycle routing while delegating
//  the UI to `StartMatchOptionsView`, `SavedMatchesListView`, and
//  `MatchSettingsListView`.
//

import SwiftUI
import RefWatchCore

struct StartMatchScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Root menu with two destinations. We inject closures to keep
        // components testable and decoupled from navigation state.
        StartMatchOptionsView(onReset: { matchViewModel.resetMatch() }) {
            SavedMatchesListView(matches: matchViewModel.savedMatches) { match in
                // Selecting a saved match updates the model then proceeds to kickoff.
                matchViewModel.selectMatch(match)
                lifecycle.goToKickoffFirst()
            }
        } createDestination: {
            MatchSettingsListView(matchViewModel: matchViewModel) { viewModel in
                // Creating a new match applies configuration then proceeds to kickoff.
                configureMatch(with: viewModel)
            }
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Start Match")
        .onChange(of: lifecycle.state) { newValue in
            // When lifecycle moves past idle, this screen should close.
            if newValue != .idle {
                dismiss()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if lifecycle.state == .idle {
                    Button {
                        modeSwitcherPresentation.wrappedValue = true
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
    }
}

private extension StartMatchScreen {
    /// Applies the current settings from the provided `MatchViewModel` to
    /// configure the match and advances the lifecycle to the kickoff screen.
    func configureMatch(with viewModel: MatchViewModel) {
        viewModel.configureMatch(
            duration: viewModel.matchDuration,
            periods: viewModel.numberOfPeriods,
            halfTimeLength: viewModel.halfTimeLength,
            hasExtraTime: viewModel.hasExtraTime,
            hasPenalties: viewModel.hasPenalties
        )
        lifecycle.goToKickoffFirst()
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
    }
}
