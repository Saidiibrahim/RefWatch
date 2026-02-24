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
  let unselectedOutlineColor: Color?
  let selectedBackgroundColor: Color?
  let unselectedBackgroundColor: Color?
  let selectedTeamNameColor: Color?
  let selectedScoreColor: Color?
  let cornerRadius: CGFloat?
  let teamNameFont: Font?
  let scoreFont: Font?
  let contentSpacing: CGFloat?
  let height: CGFloat?

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  init(
    teamName: String,
    score: Int,
    isSelected: Bool = false,
    selectedOutlineColor: Color? = nil,
    unselectedOutlineColor: Color? = nil,
    selectedBackgroundColor: Color? = nil,
    unselectedBackgroundColor: Color? = nil,
    selectedTeamNameColor: Color? = nil,
    selectedScoreColor: Color? = nil,
    cornerRadius: CGFloat? = nil,
    teamNameFont: Font? = nil,
    scoreFont: Font? = nil,
    contentSpacing: CGFloat? = nil,
    height: CGFloat? = nil)
  {
    self.teamName = teamName
    self.score = score
    self.isSelected = isSelected
    self.selectedOutlineColor = selectedOutlineColor
    self.unselectedOutlineColor = unselectedOutlineColor
    self.selectedBackgroundColor = selectedBackgroundColor
    self.unselectedBackgroundColor = unselectedBackgroundColor
    self.selectedTeamNameColor = selectedTeamNameColor
    self.selectedScoreColor = selectedScoreColor
    self.cornerRadius = cornerRadius
    self.teamNameFont = teamNameFont
    self.scoreFont = scoreFont
    self.contentSpacing = contentSpacing
    self.height = height
  }

  var body: some View {
    VStack(spacing: self.contentSpacing ?? self.theme.spacing.s) {
      Text(self.teamName)
        .font(self.teamNameFont ?? self.theme.typography.cardHeadline)
        .foregroundStyle(self.teamNameColor)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text("\(self.score)")
        .font(self.scoreFont ?? self.theme.typography.timerSecondary)
        .foregroundStyle(self.scoreColor)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .frame(height: self.height ?? self.layout.teamScoreBoxHeight)
    .background(
      RoundedRectangle(cornerRadius: self.resolvedCornerRadius, style: .continuous)
        .fill(self.backgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: self.resolvedCornerRadius, style: .continuous)
        .stroke(self.outlineColor, lineWidth: 1))
  }

  private var resolvedCornerRadius: CGFloat {
    self.cornerRadius ?? self.theme.components.cardCornerRadius
  }

  private var backgroundColor: Color {
    if self.isSelected {
      return self.selectedBackgroundColor ?? self.unselectedBackgroundColor ?? self.theme.colors.backgroundElevated
    }
    return self.unselectedBackgroundColor ?? self.theme.colors.backgroundElevated
  }

  private var teamNameColor: Color {
    if self.isSelected {
      return self.selectedTeamNameColor ?? self.theme.colors.textSecondary
    }
    return self.theme.colors.textSecondary
  }

  private var scoreColor: Color {
    if self.isSelected {
      return self.selectedScoreColor ?? self.theme.colors.textPrimary
    }
    return self.theme.colors.textPrimary
  }

  private var outlineColor: Color {
    if self.isSelected {
      return self.selectedOutlineColor ?? self.theme.colors.matchPositive
    }
    return self.unselectedOutlineColor ?? self.theme.colors.outlineMuted.opacity(0.4)
  }
}

#Preview {
  HStack(spacing: 10) {
    TeamScoreBox(teamName: "HOM", score: 1, isSelected: true)
    TeamScoreBox(teamName: "AWA", score: 0)
  }
  .padding()
}
