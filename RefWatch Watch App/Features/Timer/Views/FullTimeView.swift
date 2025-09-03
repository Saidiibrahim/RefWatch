//
//  FullTimeView.swift
//  RefWatch Watch App
//
//  Description: Full-time display showing final scores and option to end match
//

import SwiftUI

struct FullTimeView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var showingEndMatchConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Time indicator
            VStack(spacing: 4) {
                Text(formattedCurrentTime)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                Text("Full Time")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Team score boxes
            HStack(spacing: 16) {
                TeamScoreBox(
                    teamName: matchViewModel.homeTeamDisplayName,
                    score: matchViewModel.currentMatch?.homeScore ?? 0
                )
                
                TeamScoreBox(
                    teamName: matchViewModel.awayTeamDisplayName,
                    score: matchViewModel.currentMatch?.awayScore ?? 0
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.black)
        // Compact button pinned above the bottom safe area
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                #if DEBUG
                print("DEBUG: FullTimeView: End Match tapped – presenting confirmation")
                #endif
                showingEndMatchConfirmation = true
            }) {
                Text("End Match")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("endMatchButton")
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 28) // lift above page indicator / rounded corners
        }
        .confirmationDialog(
            "",
            isPresented: $showingEndMatchConfirmation,
            titleVisibility: .hidden
        ) {
            Button("Yes") {
                #if DEBUG
                print("DEBUG: FullTimeView: ConfirmationDialog Yes tapped – begin finalize")
                #endif
                matchViewModel.finalizeMatch()
                DispatchQueue.main.async {
                    lifecycle.resetToStart()
                    matchViewModel.resetMatch()
                }
            }
            .accessibilityIdentifier("endMatchConfirmYes")
            Button("No", role: .cancel) {
                #if DEBUG
                print("DEBUG: FullTimeView: ConfirmationDialog No tapped – cancelling")
                #endif
            }
            .accessibilityIdentifier("endMatchConfirmNo")
        } message: {
            Text("Are you sure you want to 'End Match'?")
        }
        .onChange(of: showingEndMatchConfirmation) { isShowing, _ in
            #if DEBUG
            print("DEBUG: FullTimeView.onChange showingEndMatchConfirmation=\(isShowing)")
            #endif
        }
        .onChange(of: matchViewModel.matchCompleted) { completed, _ in
            #if DEBUG
            print("DEBUG: FullTimeView.onChange matchCompleted=\(completed) state=\(lifecycle.state)")
            #endif
            if completed && lifecycle.state != .idle {
                lifecycle.resetToStart()
                matchViewModel.resetMatch()
            }
        }
        .onAppear {
            #if DEBUG
            print("DEBUG: FullTimeView appeared")
            #endif
        }
    }
    
    // Computed property for current time
    private var formattedCurrentTime: String {
        DateFormatter.watchShortTime.string(from: Date())
    }
}

// Team score box component
private struct TeamScoreBox: View {
    let teamName: String
    let score: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text(teamName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text("\(score)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.7))
        )
    }
}

#Preview {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    // Set up match with some scores for preview
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    viewModel.isFullTime = true
    
    return FullTimeView(matchViewModel: viewModel, lifecycle: MatchLifecycleCoordinator())
}
