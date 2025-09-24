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
    @State private var path: [Route] = []

    private enum Route: Hashable {
        case savedMatches
        case createMatch
    }

    var body: some View {
        NavigationStack(path: $path) {
            StartMatchOptionsView(
                onReset: handleReset,
                onSelectMatch: { path.append(.savedMatches) },
                onCreateMatch: { path.append(.createMatch) }
            )
            .background(theme.colors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Start Match")
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
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .savedMatches:
                    SavedMatchesListView(matches: matchViewModel.savedMatches) { match in
                        matchViewModel.selectMatch(match)
                        proceedToKickoff()
                    }
                case .createMatch:
                    MatchSettingsListView(matchViewModel: matchViewModel) { viewModel in
                        configureMatch(with: viewModel)
                        proceedToKickoff()
                    }
                }
            }
        }
        .onChange(of: lifecycle.state) { newValue in
            // When lifecycle moves past idle, close the entire start flow and reset navigation.
            if newValue != .idle {
                path.removeAll()
                dismiss()
            }
        }
    }
}

private extension StartMatchScreen {
    /// Applies the current settings from the provided `MatchViewModel` to
    /// configure the match before transitioning into kickoff.
    func configureMatch(with viewModel: MatchViewModel) {
        viewModel.configureMatch(
            duration: viewModel.matchDuration,
            periods: viewModel.numberOfPeriods,
            halfTimeLength: viewModel.halfTimeLength,
            hasExtraTime: viewModel.hasExtraTime,
            hasPenalties: viewModel.hasPenalties
        )
    }

    func proceedToKickoff() {
        lifecycle.goToKickoffFirst()
    }

    func handleReset() {
        matchViewModel.resetMatch()
        path.removeAll()
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
    }
}
