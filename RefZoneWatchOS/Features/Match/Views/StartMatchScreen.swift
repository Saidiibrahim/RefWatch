//
//  StartMatchScreen.swift
//  RefereeAssistant
//
//  Description: Hosts the start-flow hub surface and emits navigation callbacks
//  so the parent coordinator can push saved matches or match settings screens.
//

import SwiftUI
import RefWatchCore

struct StartMatchScreen: View {
    @Environment(\.theme) private var theme
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    let onNavigate: (MatchRoute) -> Void

    var body: some View {
        StartMatchOptionsView(
            onReset: handleReset,
            onSelectMatch: { onNavigate(.savedMatches) },
            onCreateMatch: { onNavigate(.createMatch) }
        )
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Start Match")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if lifecycle.state == .idle {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .onChange(of: lifecycle.state) { _, newValue in
            // When lifecycle moves past idle, close the entire start flow and reset navigation.
            if newValue != .idle {
                dismiss()
            }
        }
    }
}

private extension StartMatchScreen {
    func handleReset() {
        // Clear match state; navigation updates are coordinated by the parent.
        matchViewModel.resetMatch()
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen(
            matchViewModel: MatchViewModel(haptics: WatchHaptics()),
            lifecycle: MatchLifecycleCoordinator(),
            onNavigate: { _ in }
        )
    }
}
