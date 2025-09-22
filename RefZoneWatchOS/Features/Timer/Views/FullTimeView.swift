//
//  FullTimeView.swift
//  RefZoneWatchOS
//
//  Description: Full-time display showing final scores and option to end match
//

import SwiftUI
import WatchKit
import RefWatchCore

struct FullTimeView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var showingActionSheet = false
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.m) {
                Text("Full Time")
                    .font(theme.typography.heroSubtitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: theme.spacing.s) {
                    TeamScoreBox(
                        teamName: matchViewModel.homeTeamDisplayName,
                        score: matchViewModel.currentMatch?.homeScore ?? 0
                    )

                    TeamScoreBox(
                        teamName: matchViewModel.awayTeamDisplayName,
                        score: matchViewModel.currentMatch?.awayScore ?? 0
                    )
                }
            }
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .padding(.top, theme.spacing.s)
            .padding(.bottom, layout.safeAreaBottomPadding + theme.spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.8) {
            WKInterfaceDevice.current().play(.notification)
            showingActionSheet = true
        }
        .sheet(isPresented: $showingActionSheet) {
            MatchActionsSheet(matchViewModel: matchViewModel, lifecycle: lifecycle)
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
    @Environment(\.watchLayoutScale) private var layout

    var body: some View {
        VStack(spacing: theme.spacing.s) {
            Text(teamName)
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(score)")
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: layout.teamScoreBoxHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                .fill(theme.colors.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                .stroke(theme.colors.outlineMuted.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview("Full Time – 41mm") {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    // Set up match with some scores for preview
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    viewModel.isFullTime = true
    
    return FullTimeView(matchViewModel: viewModel, lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        .previewDevice("Apple Watch Series 9 (41mm)")
}

#Preview("Full Time – Ultra") {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    viewModel.isFullTime = true

    return FullTimeView(matchViewModel: viewModel, lifecycle: MatchLifecycleCoordinator())
        .watchLayoutScale(WatchLayoutScale(category: .expanded))
        .previewDevice("Apple Watch Ultra 2 (49mm)")
}
