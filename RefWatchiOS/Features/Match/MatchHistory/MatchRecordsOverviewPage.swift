//
//  MatchRecordsOverviewPage.swift
//  RefWatchiOS
//
//  Overview page for completed-match records confirmation.
//

import RefWatchCore
import SwiftUI

struct MatchRecordsOverviewPage: View {
  let snapshot: CompletedMatch
  @Environment(\.theme) private var theme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 10) {
          Text(self.scoreLine)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        VStack(spacing: 12) {
          MatchRecordsOverviewMetricRow(
            title: "Yellow Cards",
            value: self.totalYellowCards,
            tint: self.theme.colors.matchNeutral)
          MatchRecordsOverviewMetricRow(
            title: "Red Cards",
            value: self.totalRedCards,
            tint: self.theme.colors.matchCritical)
          MatchRecordsOverviewMetricRow(
            title: "Substitutions",
            value: self.totalSubstitutions,
            tint: self.theme.colors.accentSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollIndicators(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
  }
}

private extension MatchRecordsOverviewPage {
  var scoreLine: String {
    "\(self.snapshot.match.homeTeam) \(self.snapshot.match.homeScore) - \(self.snapshot.match.awayScore) \(self.snapshot.match.awayTeam)"
  }

  var totalYellowCards: Int {
    self.snapshot.match.homeYellowCards + self.snapshot.match.awayYellowCards
  }

  var totalRedCards: Int {
    self.snapshot.match.homeRedCards + self.snapshot.match.awayRedCards
  }

  var totalSubstitutions: Int {
    self.snapshot.match.homeSubs + self.snapshot.match.awaySubs
  }
}

private struct MatchRecordsOverviewMetricRow: View {
  let title: String
  let value: Int
  let tint: Color

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(self.tint)
        .frame(width: 10, height: 10)

      Text(self.title)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()

      Text("\(self.value)")
        .font(.headline.monospacedDigit())
        .foregroundStyle(.primary)
    }
  }
}
