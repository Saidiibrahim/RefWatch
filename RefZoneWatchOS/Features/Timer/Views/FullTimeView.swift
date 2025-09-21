//
//  FullTimeView.swift
//  RefZoneWatchOS
//
//  Description: Full-time display showing final scores and option to end match
//

import SwiftUI
import RefWatchCore

struct FullTimeView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var showingEndMatchConfirmation = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: theme.spacing.l) {
            Spacer()

            // Team score boxes
            HStack(spacing: theme.spacing.l) {
                TeamScoreBox(
                    teamName: matchViewModel.homeTeamDisplayName,
                    score: matchViewModel.currentMatch?.homeScore ?? 0
                )
                
                TeamScoreBox(
                    teamName: matchViewModel.awayTeamDisplayName,
                    score: matchViewModel.currentMatch?.awayScore ?? 0
                )
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)

            Spacer()
        }
        .background(theme.colors.backgroundPrimary)
        .navigationTitle("Full Time")
        // Compact button pinned above the bottom safe area
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                #if DEBUG
                print("DEBUG: FullTimeView: End Match tapped – presenting confirmation")
                #endif
                showingEndMatchConfirmation = true
            }) {
                Text("End Match")
                    .font(theme.typography.button)
                    .foregroundStyle(theme.colors.textInverted)
                    .frame(maxWidth: .infinity)
                    .frame(height: theme.components.buttonHeight / 1.6)
                    .background(
                        RoundedRectangle(cornerRadius: theme.components.controlCornerRadius)
                            .fill(theme.colors.matchPositive)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("endMatchButton")
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .padding(.top, theme.spacing.s)
            .padding(.bottom, theme.spacing.xl) // lift above page indicator / rounded corners
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
    
}

// Team score box component
private struct TeamScoreBox: View {
    let teamName: String
    let score: Int
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.s) {
            Text(teamName)
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textSecondary)

            Text("\(score)")
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                .fill(theme.colors.backgroundElevated)
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
