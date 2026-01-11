//
//  CompactTeamBox.swift
//  RefWatchWatchOS
//
//  Description: Compact team selection box component optimized for watch screen space
//

import RefWatchCore
import SwiftUI

/// Compact team box component optimized for watch screen space
struct CompactTeamBox: View {
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  let teamName: String
  let score: Int
  let isSelected: Bool
  let action: () -> Void
  let accessibilityIdentifier: String?

  init(
    teamName: String,
    score: Int,
    isSelected: Bool,
    action: @escaping () -> Void,
    accessibilityIdentifier: String? = nil)
  {
    self.teamName = teamName
    self.score = score
    self.isSelected = isSelected
    self.action = action
    self.accessibilityIdentifier = accessibilityIdentifier
  }

  var body: some View {
    Button(action: self.action) {
      VStack(spacing: self.theme.spacing.xs) {
        Text(self.teamName)
          .font(self.theme.typography.cardMeta.weight(.semibold))
          .foregroundStyle(self.textColor)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .layoutPriority(1)

        Text("\(self.score)")
          .font(self.theme.typography.timerSecondary)
          .foregroundStyle(self.textColor)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity)
      .frame(height: self.layout.compactTeamTileHeight)
      .padding(.horizontal, self.theme.spacing.s)
      .background(self.background)
      .overlay(self.border)
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous))
    .accessibilityIdentifier(self.accessibilityIdentifier ?? "teamBox_\(self.teamName)")
  }

  private var background: some View {
    RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
      .fill(self.isSelected ? self.theme.colors.matchPositive : self.theme.colors.backgroundElevated)
  }

  private var border: some View {
    RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
      .stroke(
        self.isSelected ? self.theme.colors.matchPositive.opacity(0.9) :
          self.theme.colors.outlineMuted.opacity(0.6),
        lineWidth: 1)
  }

  private var textColor: Color {
    self.isSelected ? self.theme.colors.textInverted : self.theme.colors.textPrimary
  }
}

#Preview {
  HStack(spacing: 10) {
    CompactTeamBox(
      teamName: "HOM",
      score: 1,
      isSelected: true,
      action: { print("Home selected") },
      accessibilityIdentifier: "homeTeamButton")

    CompactTeamBox(
      teamName: "AWA",
      score: 0,
      isSelected: false,
      action: { print("Away selected") },
      accessibilityIdentifier: "awayTeamButton")
  }
  .padding()
}
