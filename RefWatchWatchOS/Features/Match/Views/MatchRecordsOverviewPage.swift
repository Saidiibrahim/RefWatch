//
//  MatchRecordsOverviewPage.swift
//  RefWatchWatchOS
//
//  Overview page for completed-match records confirmation.
//

import RefWatchCore
import SwiftUI

struct MatchRecordsOverviewPage: View {
  let snapshot: CompletedMatch

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    ScrollView {
      ViewThatFits(in: .vertical) {
        self.standardLayout
        self.compactLayout
      }
      .padding(.horizontal, self.theme.components.cardHorizontalPadding)
      .padding(.vertical, self.theme.components.listRowVerticalInset)
    }
    .background(self.theme.colors.backgroundPrimary)
  }

  private var standardLayout: some View {
    VStack(spacing: self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14)) {
      self.scoreCard
      self.summaryCard
    }
  }

  private var compactLayout: some View {
    VStack(spacing: self.layout.dimension(self.theme.spacing.s, minimum: 8, maximum: 12)) {
      self.scoreCard
      self.summaryCard
    }
  }
}

extension MatchRecordsOverviewPage {
  private var scoreCard: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(alignment: .leading, spacing: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10)) {
        ViewThatFits(in: .vertical) {
          self.singleLineScore
          self.compactScore
        }
      }
    }
  }

  private var summaryCard: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(spacing: self.layout.dimension(self.theme.spacing.s, minimum: 8, maximum: 10)) {
        MatchRecordsOverviewStatRow(
          title: "Yellow Cards",
          value: self.totalYellowCards,
          color: self.theme.colors.matchNeutral)
        MatchRecordsOverviewStatRow(
          title: "Red Cards",
          value: self.totalRedCards,
          color: self.theme.colors.matchCritical)
        MatchRecordsOverviewStatRow(
          title: "Substitutions",
          value: self.totalSubstitutions,
          color: self.theme.colors.accentSecondary)
      }
    }
  }

  private var singleLineScore: some View {
    Text(self.scoreLine)
      .font(self.theme.typography.cardHeadline.monospacedDigit())
      .foregroundStyle(self.theme.colors.textPrimary)
      .lineLimit(2)
      .minimumScaleFactor(0.72)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var compactScore: some View {
    Text(self.scoreLine)
      .font(self.theme.typography.cardMeta.weight(.semibold).monospacedDigit())
      .foregroundStyle(self.theme.colors.textPrimary)
      .lineLimit(3)
      .minimumScaleFactor(0.72)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var scoreLine: String {
    "\(self.snapshot.match.homeTeam) \(self.snapshot.match.homeScore) - \(self.snapshot.match.awayScore) \(self.snapshot.match.awayTeam)"
  }

  private var totalYellowCards: Int {
    self.snapshot.match.homeYellowCards + self.snapshot.match.awayYellowCards
  }

  private var totalRedCards: Int {
    self.snapshot.match.homeRedCards + self.snapshot.match.awayRedCards
  }

  private var totalSubstitutions: Int {
    self.snapshot.match.homeSubs + self.snapshot.match.awaySubs
  }
}

private struct MatchRecordsOverviewStatRow: View {
  let title: String
  let value: Int
  let color: Color

  @Environment(\.theme) private var theme

  var body: some View {
    HStack(spacing: self.theme.spacing.s) {
      Circle()
        .fill(self.color)
        .frame(width: 8, height: 8)

      Text(self.title)
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)

      Spacer()

      Text("\(self.value)")
        .font(self.theme.typography.cardHeadline.monospacedDigit())
        .foregroundStyle(self.theme.colors.textPrimary)
    }
  }
}

#if DEBUG
#Preview("Overview Page") {
  MatchRecordsOverviewPage(snapshot: MatchRecordsOverviewPagePreviewFixtures.overviewSnapshot())
    .watchPreviewChrome()
}

#Preview("Overview Page - Compact") {
  MatchRecordsOverviewPage(snapshot: MatchRecordsOverviewPagePreviewFixtures.compactSnapshot())
    .watchPreviewChrome(layout: WatchPreviewSupport.compactLayout)
}

#Preview("Overview Page - Clean Match") {
  MatchRecordsOverviewPage(
    snapshot: makeSampleCompletedMatch(
      homeTeam: "Arsenal",
      awayTeam: "Chelsea",
      homeScore: 0,
      awayScore: 0,
      hasEvents: false))
    .watchPreviewChrome()
}

@MainActor
private enum MatchRecordsOverviewPagePreviewFixtures {
  static func overviewSnapshot() -> CompletedMatch {
    var snapshot = makeSampleCompletedMatch(
      homeTeam: "Arsenal",
      awayTeam: "Chelsea",
      homeScore: 2,
      awayScore: 1,
      hasEvents: true)
    snapshot.match.homeYellowCards = 1
    snapshot.match.awayYellowCards = 2
    snapshot.match.awayRedCards = 1
    snapshot.match.homeSubs = 2
    snapshot.match.awaySubs = 1
    return snapshot
  }

  static func compactSnapshot() -> CompletedMatch {
    var snapshot = makeSampleCompletedMatch(
      homeTeam: "Very Long Home Team",
      awayTeam: "Very Long Away Team",
      homeScore: 4,
      awayScore: 3,
      hasEvents: true)
    snapshot.match.homeYellowCards = 2
    snapshot.match.awayYellowCards = 2
    snapshot.match.awayRedCards = 1
    snapshot.match.homeSubs = 3
    snapshot.match.awaySubs = 2
    return snapshot
  }
}
#endif
