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
    ZStack {
      self.fullTimeBackgroundColor.ignoresSafeArea()

      GeometryReader { _ in
        ViewThatFits(in: .vertical) {
          self.fullLayout
          self.compactLayout
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      }
      .allowsHitTesting(!self.showingEndMatchConfirmation)
      .accessibilityHidden(self.showingEndMatchConfirmation)

      if self.showingEndMatchConfirmation {
        self.endMatchConfirmationOverlay
          .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: self.showingEndMatchConfirmation)
    .onChange(of: self.matchViewModel.matchCompleted) { completed, _ in
      self.handleMatchCompletedChange(completed)
    }
    .onAppear {
      self.logAppear()
    }
  }
}

extension FullTimeView {
  private var screenTitle: some View {
    Text("Full Time")
      .font(self.headerFont)
      .foregroundStyle(self.theme.colors.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityAddTraits(.isHeader)
  }

  private var fullLayout: some View {
    self.contentLayout(
      verticalSpacing: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10),
      horizontalPadding: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10),
      topPadding: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10),
      spacerMinLength: self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14))
  }

  private var compactLayout: some View {
    self.contentLayout(
      verticalSpacing: self.layout.dimension(6, minimum: 4, maximum: 7),
      horizontalPadding: self.layout.dimension(6, minimum: 5, maximum: 8),
      topPadding: self.layout.dimension(5, minimum: 4, maximum: 7),
      spacerMinLength: self.layout.dimension(7, minimum: 6, maximum: 10))
  }

  private func contentLayout(
    verticalSpacing: CGFloat,
    horizontalPadding: CGFloat,
    topPadding: CGFloat,
    spacerMinLength: CGFloat) -> some View
  {
    VStack(spacing: verticalSpacing) {
      self.screenTitle

      self.scoreBoard

      self.completeMatchButton
        .padding(.top, self.layout.dimension(4, minimum: 2, maximum: 6))

      Spacer(minLength: spacerMinLength + self.layout.safeAreaBottomPadding)
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.top, topPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var scoreBoard: some View {
    HStack(spacing: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10)) {
      TeamScoreBox(
        teamName: self.matchViewModel.homeTeamDisplayName,
        score: self.matchViewModel.currentMatch?.homeScore ?? 0,
        selectedOutlineColor: self.theme.colors.matchPositive,
        unselectedOutlineColor: self.theme.colors.outlineMuted.opacity(0.08),
        unselectedBackgroundColor: self.scoreCardBackgroundColor,
        cornerRadius: self.scoreCardCornerRadius,
        teamNameFont: self.theme.typography.cardMeta.weight(.semibold),
        scoreFont: self.theme.typography.timerSecondary,
        contentSpacing: self.layout.dimension(5, minimum: 4, maximum: 6),
        height: self.scoreCardHeight)

      TeamScoreBox(
        teamName: self.matchViewModel.awayTeamDisplayName,
        score: self.matchViewModel.currentMatch?.awayScore ?? 0,
        selectedOutlineColor: self.theme.colors.matchPositive,
        unselectedOutlineColor: self.theme.colors.outlineMuted.opacity(0.08),
        unselectedBackgroundColor: self.scoreCardBackgroundColor,
        cornerRadius: self.scoreCardCornerRadius,
        teamNameFont: self.theme.typography.cardMeta.weight(.semibold),
        scoreFont: self.theme.typography.timerSecondary,
        contentSpacing: self.layout.dimension(5, minimum: 4, maximum: 6),
        height: self.scoreCardHeight)
    }
  }

  private var completeMatchButton: some View {
    Button {
      withAnimation {
        self.showingEndMatchConfirmation = true
      }
    } label: {
      HStack(spacing: self.layout.dimension(self.theme.spacing.xs, minimum: 4, maximum: 8)) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: self.layout.dimension(16, minimum: 14, maximum: 18), weight: .semibold))
          .foregroundStyle(self.theme.colors.textInverted)

        Text("Complete Match")
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textInverted)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .frame(height: self.completeButtonHeight)
      .background(
        RoundedRectangle(cornerRadius: self.completeButtonCornerRadius, style: .continuous)
          .fill(self.theme.colors.matchPositive))
      .overlay(
        RoundedRectangle(cornerRadius: self.completeButtonCornerRadius, style: .continuous)
          .stroke(self.theme.colors.matchPositive.opacity(0.7), lineWidth: 1))
      .shadow(
        color: self.theme.colors.matchPositive.opacity(0.22),
        radius: self.layout.dimension(4, minimum: 2, maximum: 5),
        x: 0,
        y: self.layout.dimension(1, minimum: 0, maximum: 2))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("fullTimeCompleteMatchButton")
  }

  private var endMatchConfirmationOverlay: some View {
    ZStack {
      Color.black.opacity(0.64)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
          // Swallow background taps to preserve explicit confirmation choice.
        }

      VStack(spacing: self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14)) {
        VStack(spacing: self.layout.dimension(self.theme.spacing.xs, minimum: 4, maximum: 8)) {
          Text("Complete Match?")
            .font(self.theme.typography.cardHeadline.weight(.semibold))
            .foregroundStyle(self.theme.colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text("This saves the final score and returns you to start.")
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        self.endMatchConfirmationActions
      }
      .padding(.vertical, self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14))
      .padding(.horizontal, self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14))
      .background(
        RoundedRectangle(cornerRadius: self.confirmationCornerRadius, style: .continuous)
          .fill(self.confirmationCardBackgroundColor))
      .overlay(
        RoundedRectangle(cornerRadius: self.confirmationCornerRadius, style: .continuous)
          .stroke(self.theme.colors.outlineMuted.opacity(0.75), lineWidth: 1))
      .padding(.horizontal, self.layout.dimension(self.theme.spacing.s, minimum: 8, maximum: 12))
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(.isModal)
      .accessibilityIdentifier("fullTimeConfirmationOverlay")
    }
  }

  @ViewBuilder
  private var endMatchConfirmationActions: some View {
    let spacing = self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10)

    ViewThatFits {
      HStack(spacing: spacing) {
        self.endMatchCancelButton
        self.endMatchConfirmButton
      }

      VStack(spacing: spacing) {
        self.endMatchCancelButton
        self.endMatchConfirmButton
      }
    }
  }

  private var endMatchCancelButton: some View {
    self.confirmationButton(
      title: "Cancel",
      textColor: self.theme.colors.textPrimary,
      fillColor: self.confirmationSecondaryFill,
      outlineColor: self.theme.colors.outlineMuted.opacity(0.65))
    {
      withAnimation {
        self.showingEndMatchConfirmation = false
      }
    }
  }

  private var endMatchConfirmButton: some View {
    self.confirmationButton(
      title: "Complete",
      textColor: self.theme.colors.textInverted,
      fillColor: self.theme.colors.matchPositive,
      outlineColor: self.theme.colors.matchPositive.opacity(0.72))
    {
      withAnimation {
        self.showingEndMatchConfirmation = false
      }
      self.matchViewModel.finalizeMatch()
      DispatchQueue.main.async {
        self.lifecycle.resetToStart()
        self.matchViewModel.resetMatch()
      }
    }
  }

  private func confirmationButton(
    title: String,
    textColor: Color,
    fillColor: Color,
    outlineColor: Color,
    action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      Text(title)
        .font(self.theme.typography.cardMeta.weight(.semibold))
        .foregroundStyle(textColor)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
        .frame(height: self.confirmationButtonHeight)
        .background(
          RoundedRectangle(cornerRadius: self.confirmationButtonCornerRadius, style: .continuous)
            .fill(fillColor))
        .overlay(
          RoundedRectangle(cornerRadius: self.confirmationButtonCornerRadius, style: .continuous)
            .stroke(outlineColor, lineWidth: 1))
    }
    .buttonStyle(.plain)
  }

  private var scoreCardCornerRadius: CGFloat {
    self.layout.dimension(10, minimum: 8, maximum: 12)
  }

  private var scoreCardHeight: CGFloat {
    switch self.layout.category {
    case .compact:
      self.layout.dimension(64, minimum: 58, maximum: 68)
    case .standard:
      self.layout.dimension(70, minimum: 64, maximum: 74)
    case .expanded:
      self.layout.dimension(76, minimum: 70, maximum: 82)
    }
  }

  private var completeButtonHeight: CGFloat {
    switch self.layout.category {
    case .compact:
      self.layout.dimension(42, minimum: 38, maximum: 44)
    case .standard:
      self.layout.dimension(46, minimum: 42, maximum: 48)
    case .expanded:
      self.layout.dimension(50, minimum: 46, maximum: 54)
    }
  }

  private var completeButtonCornerRadius: CGFloat {
    self.layout.dimension(12, minimum: 10, maximum: 14)
  }

  private var confirmationCornerRadius: CGFloat {
    self.layout.dimension(14, minimum: 12, maximum: 16)
  }

  private var confirmationButtonCornerRadius: CGFloat {
    self.layout.dimension(11, minimum: 9, maximum: 13)
  }

  private var confirmationButtonHeight: CGFloat {
    self.layout.dimension(34, minimum: 30, maximum: 38)
  }

  private var headerFont: Font {
    .system(
      size: self.layout.dimension(19, minimum: 17, maximum: 21),
      weight: .semibold,
      design: .rounded)
  }

  private var fullTimeBackgroundColor: Color {
    .black
  }

  private var scoreCardBackgroundColor: Color {
    Color(red: 0.21, green: 0.22, blue: 0.29)
  }

  private var confirmationCardBackgroundColor: Color {
    Color(red: 0.14, green: 0.15, blue: 0.21)
  }

  private var confirmationSecondaryFill: Color {
    Color(red: 0.22, green: 0.23, blue: 0.31)
  }

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

#Preview("Full Time – Series 9 (45mm)") {
  let viewModel = MatchViewModel(haptics: WatchHaptics())
  viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
  viewModel.updateScore(isHome: true, increment: true)
  viewModel.updateScore(isHome: true, increment: true)
  viewModel.updateScore(isHome: false, increment: true)
  viewModel.isFullTime = true

  return FullTimeView(matchViewModel: viewModel, lifecycle: MatchLifecycleCoordinator())
    .watchLayoutScale(WatchLayoutScale(category: .standard))
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
