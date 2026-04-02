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
  let autoStartCountdown: Bool
  
  @State private var countdownViewModel = CountdownRingViewModel()
  @Environment(\.theme) private var theme

  init(
    matchViewModel: MatchViewModel,
    lifecycle: MatchLifecycleCoordinator,
    kickoffType: MatchLifecycleCoordinator.KickoffType,
    kickingTeam: Bool,
    autoStartCountdown: Bool = true)
  {
    self.matchViewModel = matchViewModel
    self.lifecycle = lifecycle
    self.kickoffType = kickoffType
    self.kickingTeam = kickingTeam
    self.autoStartCountdown = autoStartCountdown
  }
  
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
      guard self.autoStartCountdown else { return }
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

#if DEBUG
#Preview("Countdown View - First Half") {
  let viewModel = MatchViewModel.previewRunningRegulation()

  CountdownView(
    matchViewModel: viewModel,
    lifecycle: MatchLifecycleCoordinator(),
    kickoffType: .firstHalf,
    kickingTeam: true,
    autoStartCountdown: false
  )
  .defaultAppStorage(WatchPreviewSupport.makeDefaults(suiteName: "RefWatch.watchPreview.countdown.first-half"))
  .watchPreviewChrome()
}

#Preview("Countdown View - Second Half (Compact)") {
  CountdownView(
    matchViewModel: MatchViewModel.previewSecondHalfKickoff(),
    lifecycle: MatchLifecycleCoordinator(),
    kickoffType: .secondHalf,
    kickingTeam: false,
    autoStartCountdown: false
  )
  .defaultAppStorage(WatchPreviewSupport.makeDefaults(suiteName: "RefWatch.watchPreview.countdown.second-half"))
  .watchPreviewChrome(layout: WatchPreviewSupport.compactLayout)
}
#endif
