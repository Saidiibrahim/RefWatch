// CountdownView.swift
// Description: Standalone countdown view shown before starting match/period
// Executes kickoff actions and transitions to match setup after countdown completes

import SwiftUI
import RefWatchCore

struct CountdownView: View {
  let matchViewModel: MatchViewModel
  let lifecycle: MatchLifecycleCoordinator
  let kickoffType: MatchLifecycleCoordinator.KickoffType
  let kickingTeam: Bool // true = home, false = away
  
  @State private var countdownViewModel = CountdownRingViewModel()
  @Environment(\.theme) private var theme
  
  var body: some View {
    ZStack {
      // Background using theme
      theme.colors.backgroundPrimary
        .ignoresSafeArea()
      
      // Countdown ring view
      CountdownRingView(viewModel: countdownViewModel)
    }
    .navigationBarBackButtonHidden(true) // Hide back button during countdown
    .onAppear {
      // Start countdown when view appears
      countdownViewModel.start {
        // Execute kickoff action based on type
        executeKickoffAction()
        
        // Transition to match setup
        lifecycle.goToSetup()
      }
    }
  }
  
  /// Executes the appropriate kickoff action based on kickoffType
  private func executeKickoffAction() {
    switch kickoffType {
    case .firstHalf:
      // First half: set kicking team and start match
      matchViewModel.setKickingTeam(kickingTeam)
      matchViewModel.startMatch()
      
    case .secondHalf:
      // Second half: set kicking team and start second half
      matchViewModel.setKickingTeam(kickingTeam)
      matchViewModel.startSecondHalfManually()
      
    case .et1:
      // Extra Time first half: set kicking team and start ET first half
      matchViewModel.setKickingTeamET1(kickingTeam)
      matchViewModel.startExtraTimeFirstHalfManually()
      
    case .et2:
      // Extra Time second half: start ET second half (team already set)
      matchViewModel.startExtraTimeSecondHalfManually()
    }
  }
}

#Preview("Countdown View - First Half") {
  let viewModel = MatchViewModel(haptics: WatchHaptics())
  let lifecycle = MatchLifecycleCoordinator()
  viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
  
  return CountdownView(
    matchViewModel: viewModel,
    lifecycle: lifecycle,
    kickoffType: .firstHalf,
    kickingTeam: true
  )
}

