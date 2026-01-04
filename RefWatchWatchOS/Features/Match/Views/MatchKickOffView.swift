// MatchKickOffView.swift
// Description: Screen shown before match/period start to select kicking team

import RefWatchCore
import SwiftUI

struct MatchKickOffView: View {
  let matchViewModel: MatchViewModel
  let isSecondHalf: Bool
  let defaultSelectedTeam: Team?
  let etPhase: Int? // 1 or 2 for Extra Time phases; nil for regulation
  let lifecycle: MatchLifecycleCoordinator

  @State private var selectedTeam: Team?
  @State private var isShowingMatchSettings = false
  @State private var isShowingDurationDialog = false
  // Persisted countdown enabled setting
  @AppStorage("countdown_enabled") private var countdownEnabled: Bool = true
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  enum Team {
    case home, away
  }

  // Convenience initializer for first half (original usage)
  init(matchViewModel: MatchViewModel, lifecycle: MatchLifecycleCoordinator) {
    self.matchViewModel = matchViewModel
    self.isSecondHalf = false
    self.defaultSelectedTeam = nil
    self.etPhase = nil
    self.lifecycle = lifecycle
    // Initialize @State with nil for first half
    self._selectedTeam = State(initialValue: nil)
  }

  // Initializer for second half usage
  init(
    matchViewModel: MatchViewModel,
    isSecondHalf: Bool,
    defaultSelectedTeam: Team,
    lifecycle: MatchLifecycleCoordinator)
  {
    self.matchViewModel = matchViewModel
    self.isSecondHalf = isSecondHalf
    self.defaultSelectedTeam = defaultSelectedTeam
    self.etPhase = nil
    self.lifecycle = lifecycle
    // Initialize @State with nil - will be set in onAppear
    self._selectedTeam = State(initialValue: nil)
  }

  // Initializer for Extra Time kickoff (phase 1 or 2)
  init(matchViewModel: MatchViewModel, extraTimePhase: Int, lifecycle: MatchLifecycleCoordinator) {
    self.matchViewModel = matchViewModel
    self.isSecondHalf = false
    self.defaultSelectedTeam = nil
    self.etPhase = extraTimePhase
    self.lifecycle = lifecycle
    self._selectedTeam = State(initialValue: nil)
  }

  // Initializer for Extra Time second half with default team
  init(
    matchViewModel: MatchViewModel,
    extraTimePhase: Int,
    defaultSelectedTeam: Team,
    lifecycle: MatchLifecycleCoordinator)
  {
    self.matchViewModel = matchViewModel
    self.isSecondHalf = false
    self.defaultSelectedTeam = defaultSelectedTeam
    self.etPhase = extraTimePhase
    self.lifecycle = lifecycle
    self._selectedTeam = State(initialValue: nil)
  }

  var body: some View {
    ZStack {
      GeometryReader { _ in
        ViewThatFits(in: .vertical) {
          self.fullLayout
          self.compactLayout
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
      .safeAreaInset(edge: .bottom) {
        self.confirmButton
          .padding(.top, self.confirmButtonTopPadding) // Use responsive padding
          .padding(.horizontal, self.theme.spacing.m)
          .padding(.bottom, self.layout.safeAreaBottomPadding)
      }
      .sheet(isPresented: self.$isShowingMatchSettings) {
        NavigationStack {
          MatchSettingsListView(
            matchViewModel: self.matchViewModel,
            primaryActionLabel: "Apply Settings")
          { viewModel in
            viewModel.applySettingsToCurrentMatch(viewModel.currentSettings)
            withAnimation {
              self.isShowingMatchSettings = false
            }
          }
        }
      }
      .confirmationDialog(
        "Half Duration",
        isPresented: self.$isShowingDurationDialog,
        presenting: self.allowsDurationShortcut ? self.perPeriodDurationLabel : nil,
        actions: { _ in
          Button("Change Duration") {
            self.isShowingDurationDialog = false
            self.isShowingMatchSettings = true
          }
          Button("Cancel", role: .cancel) {}
        },
        message: { durationLabel in
          Text(durationLabel)
        })
      .navigationBarBackButtonHidden()
      .onAppear {
        // Set the default selected team for second half
        if self.isSecondHalf, let defaultTeam = defaultSelectedTeam {
          self.selectedTeam = defaultTeam
        }
        // Set default for ET second half if provided
        if let phase = etPhase, phase == 2, let defaultTeam = defaultSelectedTeam {
          self.selectedTeam = defaultTeam
        }
      }
    }
  }

  private var screenTitle: String {
    if let phase = etPhase {
      return phase == 1 ? "ET 1" : "ET 2"
    }
    return self.isSecondHalf ? "Second Half" : "Kick Off"
  }

  // Per-period duration label derived from current match when available
  private var perPeriodDurationLabel: String {
    if let m = matchViewModel.currentMatch {
      // Use ET half length when in Extra Time kickoff
      if self.etPhase != nil {
        let et = max(0, Int(m.extraTimeHalfLength))
        let mm = et / 60
        let ss = et % 60
        return String(format: "%02d:%02d ▼", mm, ss)
      } else {
        let periods = max(1, m.numberOfPeriods)
        let per = m.duration / TimeInterval(periods)
        let perClamped = max(0, per)
        let mm = Int(perClamped) / 60
        let ss = Int(perClamped) % 60
        return String(format: "%02d:%02d ▼", mm, ss)
      }
    } else {
      return "\(self.matchViewModel.matchDuration / 2):00 ▼"
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
      Text(self.screenTitle)
        .font(self.theme.typography.heroSubtitle)
        .foregroundStyle(self.theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
  }

  private var fullLayout: some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.l) {
      self.header

      // Team buttons section
      VStack(spacing: self.theme.spacing.m) {
        HStack(spacing: self.theme.spacing.m) {
          self.kickoffTeamButton(
            title: self.matchViewModel.homeTeamDisplayName,
            score: self.matchViewModel.currentMatch?.homeScore ?? 0,
            isSelected: self.selectedTeam == .home,
            action: { self.selectedTeam = .home },
            accessibilityIdentifier: "homeTeamButton")
            .accessibilityLabel("Home")

          self.kickoffTeamButton(
            title: self.matchViewModel.awayTeamDisplayName,
            score: self.matchViewModel.currentMatch?.awayScore ?? 0,
            isSelected: self.selectedTeam == .away,
            action: { self.selectedTeam = .away },
            accessibilityIdentifier: "awayTeamButton")
            .accessibilityLabel("Away")
        }
      }

      Spacer(minLength: self.theme.spacing.l)
    }
    .padding(.horizontal, self.theme.spacing.m)
    .padding(.top, self.theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var compactLayout: some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.s) {
      self.header

      // Team buttons section with tighter spacing
      VStack(spacing: self.theme.spacing.s) {
        HStack(spacing: self.theme.spacing.s) {
          self.kickoffTeamButton(
            title: self.matchViewModel.homeTeamDisplayName,
            score: self.matchViewModel.currentMatch?.homeScore ?? 0,
            isSelected: self.selectedTeam == .home,
            action: { self.selectedTeam = .home },
            accessibilityIdentifier: "homeTeamButton")
            .accessibilityLabel("Home")

          self.kickoffTeamButton(
            title: self.matchViewModel.awayTeamDisplayName,
            score: self.matchViewModel.currentMatch?.awayScore ?? 0,
            isSelected: self.selectedTeam == .away,
            action: { self.selectedTeam = .away },
            accessibilityIdentifier: "awayTeamButton")
            .accessibilityLabel("Away")
        }
      }

      Spacer(minLength: self.theme.spacing.xs)
    }
    .padding(.horizontal, self.theme.spacing.m)
    .padding(.top, self.theme.spacing.s)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func kickoffTeamButton(
    title: String,
    score: Int,
    isSelected: Bool,
    action: @escaping () -> Void,
    accessibilityIdentifier: String) -> some View
  {
    CompactTeamBox(
      teamName: title,
      score: score,
      isSelected: isSelected,
      action: action,
      accessibilityIdentifier: accessibilityIdentifier)
  }

  // Responsive spacing for confirm button - more space needed on smaller screens
  private var confirmButtonTopPadding: CGFloat {
    switch self.layout.category {
    case .compact:
      self.theme.spacing.xl // 24pt on compact screens for better visual balance
    case .standard:
      self.theme.spacing.l // 16pt on standard screens
    case .expanded:
      self.theme.spacing.l // 16pt on expanded screens (Ultra looks good already)
    }
  }

  // Note: No additional bottom content padding is required now that
  // the duration chip and confirm button are placed inside the inset.

  private var confirmButton: some View {
    ZStack {
      IconButton(
        icon: "checkmark.circle.fill",
        color: self.selectedTeam != nil
          ? self.theme.colors.matchPositive
          : self.theme.colors.matchPositive.opacity(0.35)) { self.confirmKickOff() }
        .disabled(self.selectedTeam == nil)
        .accessibilityIdentifier("kickoffConfirmButton")
        .animation(.easeInOut(duration: 0.2), value: self.selectedTeam != nil)
    }
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 0.8)
        .onEnded { _ in
          guard self.allowsDurationShortcut else { return }
          self.isShowingDurationDialog = true
        })
  }

  private var allowsDurationShortcut: Bool {
    if self.isSecondHalf { return false }
    if let phase = etPhase, phase != 1 { return false }
    return true
  }

  private func confirmKickOff() {
    guard let team = selectedTeam else { return }

    // Determine kickoff type based on current context
    let kickoffType: MatchLifecycleCoordinator.KickoffType = if let phase = etPhase {
      phase == 1 ? .et1 : .et2
    } else if self.isSecondHalf {
      .secondHalf
    } else {
      .firstHalf
    }

    // Check if countdown is enabled
    if self.countdownEnabled {
      // Transition to countdown view with kickoff context
      self.lifecycle.goToCountdown(kickoffType: kickoffType, team: team == .home)
    } else {
      // Skip countdown: directly execute kickoff action and transition to setup
      self.executeKickoffAction(kickoffType: kickoffType, team: team == .home)
      self.lifecycle.goToSetup()
    }
  }

  /// Executes the appropriate kickoff action based on kickoffType
  /// - Parameters:
  ///   - kickoffType: The type of kickoff (firstHalf, secondHalf, et1, et2)
  ///   - team: true for home team, false for away team
  private func executeKickoffAction(kickoffType: MatchLifecycleCoordinator.KickoffType, team: Bool) {
    switch kickoffType {
    case .firstHalf:
      // First half: set kicking team and start match
      self.matchViewModel.setKickingTeam(team)
      self.matchViewModel.startMatch()

    case .secondHalf:
      // Second half: set kicking team and start second half
      self.matchViewModel.setKickingTeam(team)
      self.matchViewModel.startSecondHalfManually()

    case .et1:
      // Extra Time first half: set kicking team and start ET first half
      self.matchViewModel.setKickingTeamET1(team)
      self.matchViewModel.startExtraTimeFirstHalfManually()

    case .et2:
      // Extra Time second half: start ET second half (team already set)
      self.matchViewModel.startExtraTimeSecondHalfManually()
    }
  }
}

#Preview("Kickoff – 41mm") {
  let viewModel = MatchViewModel(haptics: WatchHaptics())
  let lifecycle = MatchLifecycleCoordinator()
  viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)

  return MatchKickOffView(matchViewModel: viewModel, lifecycle: lifecycle)
    .watchLayoutScale(WatchLayoutScale(category: .compact))
}

#Preview("Kickoff – Ultra") {
  let viewModel = MatchViewModel(haptics: WatchHaptics())
  viewModel.configureMatch(duration: 120, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
  viewModel.updateScore(isHome: true, increment: true)
  viewModel.updateScore(isHome: false, increment: true)
  let lifecycle = MatchLifecycleCoordinator()

  return MatchKickOffView(
    matchViewModel: viewModel,
    isSecondHalf: true,
    defaultSelectedTeam: .away,
    lifecycle: lifecycle)
    .watchLayoutScale(WatchLayoutScale(category: .expanded))
}
