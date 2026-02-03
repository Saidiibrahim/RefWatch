//
//  FullTimeView.swift
//  RefWatchWatchOS
//
//  Description: Full-time display showing final scores and option to end match
//

import RefWatchCore
import SwiftUI
import WatchKit

struct FullTimeView: View {
  let matchViewModel: MatchViewModel
  let lifecycle: MatchLifecycleCoordinator
  @State private var showingEndMatchConfirmation = false
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    ScrollView {
      VStack(spacing: self.theme.spacing.m) {
        Text("Full Time")
          .font(self.theme.typography.heroSubtitle)
          .foregroundStyle(self.theme.colors.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: self.theme.spacing.s) {
          TeamScoreBox(
            teamName: self.matchViewModel.homeTeamDisplayName,
            score: self.matchViewModel.currentMatch?.homeScore ?? 0)

          TeamScoreBox(
            teamName: self.matchViewModel.awayTeamDisplayName,
            score: self.matchViewModel.currentMatch?.awayScore ?? 0)
        }

        HStack {
          ThemeCardContainer(
            role: .positive,
            minHeight: self.layout.dimension(self.theme.components.buttonHeight, minimum: 44)
          ) {
            Button(action: {
              self.showingEndMatchConfirmation = true
            }, label: {
              Text("Complete Match")
                .font(self.theme.typography.cardHeadline)
                .foregroundStyle(self.theme.colors.textInverted)
                .frame(maxWidth: .infinity, alignment: .center)
            })
            .buttonStyle(.plain)
          }
          .frame(maxWidth: self.layout.dimension(150, minimum: 120, maximum: 180))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, self.theme.spacing.m)
        .padding(.bottom, self.layout.safeAreaBottomPadding + self.theme.spacing.xl)
      }
      .padding(.horizontal, self.theme.components.cardHorizontalPadding)
      .padding(.top, self.theme.spacing.s)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .confirmationDialog(
      "",
      isPresented: self.$showingEndMatchConfirmation,
      titleVisibility: .hidden)
    {
      Button("Yes") {
        self.matchViewModel.finalizeMatch()
        DispatchQueue.main.async {
          self.lifecycle.resetToStart()
          self.matchViewModel.resetMatch()
        }
      }
      Button("No", role: .cancel) {}
    } message: {
      Text("Are you sure you want to 'End Match'?")
    }
    .onChange(of: self.matchViewModel.matchCompleted) { completed, _ in
        self.handleMatchCompletedChange(completed)
      }
      .onAppear {
        self.logAppear()
      }
  }
}

extension FullTimeView {
  private func handleMatchCompletedChange(_ completed: Bool) {
    #if DEBUG
    print("DEBUG: FullTimeView.onChange matchCompleted=\(completed) state=\(self.lifecycle.state)")
    #endif
    if completed, self.lifecycle.state != .idle {
      self.lifecycle.resetToStart()
      self.matchViewModel.resetMatch()
    }
  }

  private func logAppear() {
    #if DEBUG
    print("DEBUG: FullTimeView appeared")
    #endif
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
}

#Preview("Full Time – Ultra") {
  let viewModel = MatchViewModel(haptics: WatchHaptics())
  viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
  viewModel.updateScore(isHome: true, increment: true)
  viewModel.updateScore(isHome: false, increment: true)
  viewModel.isFullTime = true

  return FullTimeView(matchViewModel: viewModel, lifecycle: MatchLifecycleCoordinator())
    .watchLayoutScale(WatchLayoutScale(category: .expanded))
}
