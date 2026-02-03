//
//  TeamScoreBox.swift
//  RefWatchWatchOS
//
//  Description: Team score display box with optional selection outline
//

import RefWatchCore
import SwiftUI

struct TeamScoreBox: View {
  let teamName: String
  let score: Int
  let isSelected: Bool
  let selectedOutlineColor: Color?

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  init(
    teamName: String,
    score: Int,
    isSelected: Bool = false,
    selectedOutlineColor: Color? = nil)
  {
    self.teamName = teamName
    self.score = score
    self.isSelected = isSelected
    self.selectedOutlineColor = selectedOutlineColor
  }

  var body: some View {
    VStack(spacing: self.theme.spacing.s) {
      Text(self.teamName)
        .font(self.theme.typography.cardHeadline)
        .foregroundStyle(self.theme.colors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text("\(self.score)")
        .font(self.theme.typography.timerSecondary)
        .foregroundStyle(self.theme.colors.textPrimary)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .frame(height: self.layout.teamScoreBoxHeight)
    .background(
      RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius)
        .fill(self.theme.colors.backgroundElevated))
    .overlay(
      RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius)
        .stroke(self.outlineColor, lineWidth: 1))
  }

  private var outlineColor: Color {
    if self.isSelected {
      return self.selectedOutlineColor ?? self.theme.colors.matchPositive
    }
    return self.theme.colors.outlineMuted.opacity(0.4)
  }
}

#Preview {
  HStack(spacing: 10) {
    TeamScoreBox(teamName: "HOM", score: 1, isSelected: true)
    TeamScoreBox(teamName: "AWA", score: 0)
  }
  .padding()
}
