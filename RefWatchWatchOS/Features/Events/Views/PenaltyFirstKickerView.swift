//
//  PenaltyFirstKickerView.swift
//  RefWatchWatchOS
//
//  Description: Dedicated screen to select the first kicker before entering penalties.
//

import RefWatchCore
import SwiftUI
import WatchKit

struct PenaltyFirstKickerView: View {
  let matchViewModel: MatchViewModel
  let lifecycle: MatchLifecycleCoordinator
  @State private var isRouting = false
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    GeometryReader { _ in
      VStack(alignment: .leading, spacing: self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s)) {
        self.header

        HStack(spacing: self.layout.dimension(self.theme.spacing.s, minimum: self.theme.spacing.xs)) {
          self.firstKickerButton(
            title: self.matchViewModel.homeTeamDisplayName,
            side: .home,
            color: self.theme.colors.accentPrimary)
          self.firstKickerButton(
            title: self.matchViewModel.awayTeamDisplayName,
            side: .away,
            color: self.theme.colors.accentMuted)
        }

        Spacer(minLength: self.theme.spacing.xs)
      }
      .padding(.horizontal, self.theme.spacing.m)
      .padding(.top, self.theme.spacing.s)
      .padding(.bottom, self.layout.safeAreaBottomPadding)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private func firstKickerButton(title: String, side: TeamSide, color: Color) -> some View {
    Button(action: {
      // Haptic feedback and simple tap guard to avoid double navigation
      WKInterfaceDevice.current().play(.click)
      guard !self.isRouting else { return }
      self.isRouting = true

      // Coordinated penalty setup to prevent partial state corruption:
      // - startPenalties(withFirstKicker:) atomically begins the shootout and sets first kicker
      // - Only navigate if setup succeeds (returns true)
      // - On failure, we provide failure haptic feedback and keep the user on this screen
      // This replaces the previous multi-step beginPenaltiesIfNeeded() + setPenaltyFirstKicker() approach.
      let ok = self.matchViewModel.startPenalties(withFirstKicker: side)
      if ok {
        self.lifecycle.goToPenalties()
      } else {
        // If coordination failed (defensive), reset guard and notify via haptic
        self.isRouting = false
        WKInterfaceDevice.current().play(.failure)
      }
    }, label: {
      Text(title)
        .font(self.theme.typography.heroSubtitle)
        .foregroundStyle(self.theme.colors.textInverted)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .frame(height: self.layout.dimension(self.theme.components.buttonHeight * 0.85, minimum: 40))
        .background(
          RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
            .fill(color))
    })
    .buttonStyle(.plain)
    .disabled(self.isRouting)
    .accessibilityIdentifier(side == .home ? "firstKickerHomeBtn" : "firstKickerAwayBtn")
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
      Text("First Kicker")
        .font(self.theme.typography.heroSubtitle)
        .foregroundStyle(self.theme.colors.textPrimary)

      Text("Choose which team begins the shootout")
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
  }
}

#Preview("First Kicker – 41mm") {
  PenaltyFirstKickerView(
    matchViewModel: MatchViewModel(haptics: WatchHaptics()),
    lifecycle: MatchLifecycleCoordinator())
    .watchLayoutScale(WatchLayoutScale(category: .compact))
}

#Preview("First Kicker – Ultra") {
  PenaltyFirstKickerView(
    matchViewModel: MatchViewModel(haptics: WatchHaptics()),
    lifecycle: MatchLifecycleCoordinator())
    .watchLayoutScale(WatchLayoutScale(category: .expanded))
}
