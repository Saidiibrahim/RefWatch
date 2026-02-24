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
      .background(self.kickoffBackgroundColor.ignoresSafeArea())
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
    return self.isSecondHalf ? "Second Half" : "Kick off"
  }

  // Per-period duration label derived from current match when available
  private var perPeriodDurationText: String {
    if let m = matchViewModel.currentMatch {
      // Use ET half length when in Extra Time kickoff
      if self.etPhase != nil {
        let et = max(0, Int(m.extraTimeHalfLength))
        let mm = et / 60
        let ss = et % 60
        return String(format: "%02d:%02d", mm, ss)
      } else {
        let periods = max(1, m.numberOfPeriods)
        let per = m.duration / TimeInterval(periods)
        let perClamped = max(0, per)
        let mm = Int(perClamped) / 60
        let ss = Int(perClamped) % 60
        return String(format: "%02d:%02d", mm, ss)
      }
    } else {
      let perHalfMinutes = max(0, self.matchViewModel.matchDuration / 2)
      return String(format: "%02d:00", perHalfMinutes)
    }
  }

  private var header: some View {
    Text(self.screenTitle)
      .font(self.headerTitleFont)
      .foregroundStyle(self.theme.colors.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .padding(.trailing, self.layout.dimension(2, minimum: 1, maximum: 3))
      .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private var fullLayout: some View {
    self.kickoffLayout(
      verticalSpacing: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10),
      teamSpacing: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10),
      horizontalPadding: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10),
      topPadding: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10),
      spacerMinLength: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 12))
  }

  private var compactLayout: some View {
    self.kickoffLayout(
      verticalSpacing: self.layout.dimension(7, minimum: 4, maximum: 7),
      teamSpacing: self.layout.dimension(7, minimum: 5, maximum: 7),
      horizontalPadding: self.layout.dimension(7, minimum: 5, maximum: 7),
      topPadding: self.layout.dimension(6, minimum: 4, maximum: 7),
      spacerMinLength: self.layout.dimension(1, minimum: 0, maximum: 4))
  }

  private func kickoffLayout(
    verticalSpacing: CGFloat,
    teamSpacing: CGFloat,
    horizontalPadding: CGFloat,
    topPadding: CGFloat,
    spacerMinLength: CGFloat) -> some View
  {
    VStack(spacing: verticalSpacing) {
      self.header

      HStack(spacing: teamSpacing) {
        self.kickoffTeamButton(
          title: self.matchViewModel.homeTeamDisplayName,
          score: self.matchViewModel.currentMatch?.homeScore ?? 0,
          isSelected: self.selectedTeam == .home,
          action: { self.selectedTeam = .home },
          accessibilityIdentifier: "homeTeamButton")
          .accessibilityLabel("Home")
          .accessibilityValue(self.selectedTeam == .home ? "Selected" : "Not selected")

        self.kickoffTeamButton(
          title: self.matchViewModel.awayTeamDisplayName,
          score: self.matchViewModel.currentMatch?.awayScore ?? 0,
          isSelected: self.selectedTeam == .away,
          action: { self.selectedTeam = .away },
          accessibilityIdentifier: "awayTeamButton")
          .accessibilityLabel("Away")
          .accessibilityValue(self.selectedTeam == .away ? "Selected" : "Not selected")
      }

      self.durationChip
        .padding(.top, self.layout.dimension(1, minimum: 0, maximum: 3))

      self.confirmButton
        .padding(.top, self.layout.dimension(5, minimum: 3, maximum: 7))

      Spacer(minLength: spacerMinLength + self.layout.safeAreaBottomPadding)
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.top, topPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var durationChip: some View {
    let chipContent = HStack(spacing: self.layout.dimension(self.theme.spacing.xs, minimum: 4, maximum: 6)) {
      Text(self.perPeriodDurationText)
        .font(self.theme.typography.timerTertiary.weight(.bold))
        .monospacedDigit()
        .foregroundStyle(self.theme.colors.matchPositive)

      if self.allowsDurationShortcut {
        Image(systemName: "chevron.down")
          .font(
            .system(
              size: self.layout.dimension(13, minimum: 12, maximum: 14),
              weight: .semibold,
              design: .rounded))
          .foregroundStyle(self.theme.colors.textSecondary.opacity(0.9))
      }
    }
    .padding(.horizontal, self.layout.dimension(11, minimum: 10, maximum: 13))
    .frame(height: self.durationChipHeight)
    .background(
      RoundedRectangle(cornerRadius: self.durationChipCornerRadius, style: .continuous)
        .fill(self.durationChipBackgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: self.durationChipCornerRadius, style: .continuous)
        .stroke(self.theme.colors.outlineMuted.opacity(0.72), lineWidth: 1))

    return Button {
      guard self.allowsDurationShortcut else { return }
      self.isShowingMatchSettings = true
    } label: {
      chipContent
        .frame(minHeight: self.durationChipHitAreaHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Half Duration")
    .accessibilityValue(self.perPeriodDurationText)
    .accessibilityHint(self.allowsDurationShortcut ? "Opens match settings" : "Duration locked for this phase")
    .disabled(!self.allowsDurationShortcut)
    .opacity(self.allowsDurationShortcut ? 1 : 0.85)
  }

  private func kickoffTeamButton(
    title: String,
    score: Int,
    isSelected: Bool,
    action: @escaping () -> Void,
    accessibilityIdentifier: String) -> some View
  {
    Button(action: action) {
      TeamScoreBox(
        teamName: title,
        score: score,
        isSelected: isSelected,
        selectedOutlineColor: self.theme.colors.matchPositive,
        unselectedOutlineColor: self.theme.colors.outlineMuted.opacity(0.08),
        selectedBackgroundColor: self.theme.colors.matchPositive,
        unselectedBackgroundColor: self.unselectedCardBackgroundColor,
        selectedTeamNameColor: Color.black.opacity(0.85),
        selectedScoreColor: Color.black.opacity(0.9),
        cornerRadius: self.teamCardCornerRadius,
        teamNameFont: self.theme.typography.cardMeta.weight(.semibold),
        scoreFont: self.theme.typography.timerSecondary,
        contentSpacing: self.layout.dimension(5, minimum: 4, maximum: 6),
        height: self.teamCardHeight)
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: self.teamCardCornerRadius, style: .continuous))
    .accessibilityIdentifier(accessibilityIdentifier)
  }

  private var teamCardCornerRadius: CGFloat {
    self.layout.dimension(10, minimum: 8, maximum: 12)
  }

  private var teamCardHeight: CGFloat {
    switch self.layout.category {
    case .compact:
      self.layout.dimension(64, minimum: 56, maximum: 68)
    case .standard:
      self.layout.dimension(70, minimum: 64, maximum: 74)
    case .expanded:
      self.layout.dimension(74, minimum: 68, maximum: 80)
    }
  }

  private var durationChipCornerRadius: CGFloat {
    self.layout.dimension(11, minimum: 9, maximum: 13)
  }

  private var durationChipHeight: CGFloat {
    switch self.layout.category {
    case .compact:
      self.layout.dimension(34, minimum: 30, maximum: 36)
    case .standard:
      self.layout.dimension(32, minimum: 30, maximum: 36)
    case .expanded:
      self.layout.dimension(34, minimum: 32, maximum: 38)
    }
  }

  private var durationChipHitAreaHeight: CGFloat {
    switch self.layout.category {
    case .compact:
      self.layout.dimension(36, minimum: 34, maximum: 40)
    case .standard:
      self.layout.dimension(40, minimum: 38, maximum: 44)
    case .expanded:
      self.layout.dimension(44, minimum: 42, maximum: 48)
    }
  }

  private var headerTitleFont: Font {
    .system(
      size: self.layout.dimension(19, minimum: 16, maximum: 21),
      weight: .semibold,
      design: .rounded)
  }

  private var confirmButton: some View {
    Button(action: self.confirmKickOff) {
      Image(systemName: "checkmark")
        .font(.system(size: self.confirmButtonDiameter * 0.5, weight: .bold))
        .foregroundStyle(self.theme.colors.textPrimary.opacity(self.selectedTeam != nil ? 1 : 0.5))
        .frame(width: self.confirmButtonDiameter, height: self.confirmButtonDiameter)
        .background(
          Circle()
            .fill(self.selectedTeam != nil
              ? self.theme.colors.matchPositive
              : self.theme.colors.matchPositive.opacity(0.2)))
        .overlay(
          Circle()
            .stroke(
              self.theme.colors.matchPositive.opacity(self.selectedTeam != nil ? 0.72 : 0.14),
              lineWidth: self.selectedTeam != nil ? 1.5 : 1))
        .shadow(
          color: self.selectedTeam != nil
            ? self.theme.colors.matchPositive.opacity(0.2)
            : .clear,
          radius: self.layout.dimension(3, minimum: 2, maximum: 4),
          x: 0,
          y: self.layout.dimension(1, minimum: 0, maximum: 2))
    }
    .buttonStyle(.plain)
    .disabled(self.selectedTeam == nil)
    .accessibilityIdentifier("kickoffConfirmButton")
    .accessibilityLabel("Confirm kickoff")
    .animation(.easeInOut(duration: 0.2), value: self.selectedTeam != nil)
  }

  private var allowsDurationShortcut: Bool {
    if self.isSecondHalf { return false }
    if let phase = etPhase, phase != 1 { return false }
    return true
  }

  private var confirmButtonDiameter: CGFloat {
    switch self.layout.category {
    case .compact:
      self.layout.dimension(58, minimum: 52, maximum: 62)
    case .standard:
      self.layout.dimension(66, minimum: 60, maximum: 70)
    case .expanded:
      self.layout.dimension(70, minimum: 64, maximum: 76)
    }
  }

  private var kickoffBackgroundColor: Color {
    .black
  }

  private var unselectedCardBackgroundColor: Color {
    Color(red: 0.21, green: 0.22, blue: 0.29)
  }

  private var durationChipBackgroundColor: Color {
    Color(red: 0.18, green: 0.19, blue: 0.26)
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

@MainActor
private func makeKickoffPreviewViewModel() -> MatchViewModel {
  let viewModel = MatchViewModel(haptics: WatchHaptics())
  viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
  return viewModel
}

#Preview("Kickoff – Series 9 (45mm)") {
  let lifecycle = MatchLifecycleCoordinator()
  let viewModel = makeKickoffPreviewViewModel()

  return MatchKickOffView(matchViewModel: viewModel, lifecycle: lifecycle)
}
