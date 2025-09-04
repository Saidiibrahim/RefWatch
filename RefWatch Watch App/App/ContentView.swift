//
//  ContentView.swift
//  RefereeAssistant
//
//  Description: The Welcome page with two main options: "Start Match" and "Settings".
//

import SwiftUI
import RefWatchCore

struct ContentView: View {
    @State private var matchViewModel = MatchViewModel(haptics: WatchHaptics())
    @State private var settingsViewModel = SettingsViewModel()
    @State private var lifecycle = MatchLifecycleCoordinator()
    @State private var showPersistenceError = false
    
    var body: some View {
        NavigationStack {
            Group {
                switch lifecycle.state {
                case .idle:
                    VStack(spacing: 20) {
                        Text("Welcome to Referee Assistant")
                            .font(.headline)
                            .padding(.top)
                        
                        VStack(spacing: 16) {
                            // Start Match flow
                            NavigationLinkButton(
                                title: "Start Match",
                                icon: "play.circle.fill",
                                destination: StartMatchScreen(matchViewModel: matchViewModel, lifecycle: lifecycle),
                                backgroundColor: .green
                            )
                            
                            // App settings
                            NavigationLinkButton(
                                title: "Settings",
                                icon: "gear",
                                destination: SettingsScreen(settingsViewModel: settingsViewModel),
                                backgroundColor: .gray
                            )

                            // Optional: History browser for completed matches
                            NavigationLinkButton(
                                title: "History",
                                icon: "clock.arrow.circlepath",
                                destination: MatchHistoryView(matchViewModel: matchViewModel),
                                backgroundColor: .blue
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                case .kickoffFirstHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .setup:
                    MatchSetupView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .kickoffSecondHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        isSecondHalf: true,
                        defaultSelectedTeam: (matchViewModel.getSecondHalfKickingTeam() == .home) ? .home : .away,
                        lifecycle: lifecycle
                    )
                case .kickoffExtraTimeFirstHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        extraTimePhase: 1,
                        lifecycle: lifecycle
                    )
                case .kickoffExtraTimeSecondHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        extraTimePhase: 2,
                        defaultSelectedTeam: (matchViewModel.getETSecondHalfKickingTeam() == .home) ? .home : .away,
                        lifecycle: lifecycle
                    )
                case .choosePenaltyFirstKicker:
                    PenaltyFirstKickerView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .penalties:
                    PenaltyShootoutView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .finished:
                    FullTimeView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                }
            }
        }
        .onChange(of: matchViewModel.matchCompleted) { completed, _ in
            #if DEBUG
            print("DEBUG: ContentView.onChange matchCompleted=\(completed) state=\(lifecycle.state)")
            #endif
            // Defensive fallback to guarantee return to idle after finalize
            if completed && lifecycle.state != .idle {
                lifecycle.resetToStart()
                matchViewModel.resetMatch()
            }
        }
        .onChange(of: lifecycle.state) { newState in
            #if DEBUG
            print("DEBUG: ContentView.onChange lifecycle.state=\(newState)")
            #endif
        }
        .onChange(of: matchViewModel.lastPersistenceError) { newValue, _ in
            if newValue != nil { showPersistenceError = true }
        }
        .alert("Save Failed", isPresented: $showPersistenceError) {
            Button("OK") { matchViewModel.lastPersistenceError = nil }
        } message: {
            Text(matchViewModel.lastPersistenceError ?? "An unknown error occurred while saving.")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
