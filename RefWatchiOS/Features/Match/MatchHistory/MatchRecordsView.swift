//
//  MatchRecordsView.swift
//  RefWatchiOS
//
//  Three-page completed-match records confirmation flow.
//

import RefWatchCore
import SwiftUI

struct MatchRecordsView: View {
  let snapshot: CompletedMatch
  @State private var selectedPage: Int

  static let preferredHeight: CGFloat = 440

  init(snapshot: CompletedMatch, initialPage: Int = 1) {
    self.snapshot = snapshot
    self._selectedPage = State(initialValue: initialPage)
  }

  var body: some View {
    TabView(selection: self.$selectedPage) {
      MatchRecordsTeamPage(snapshot: self.snapshot, team: .home)
        .tag(0)

      MatchRecordsOverviewPage(snapshot: self.snapshot)
        .tag(1)

      MatchRecordsTeamPage(snapshot: self.snapshot, team: .away)
        .tag(2)
    }
    .tabViewStyle(.page(indexDisplayMode: .automatic))
    .background(Color(uiColor: .systemGroupedBackground))
  }
}

#if DEBUG
#Preview("Records View") {
  NavigationStack {
    MatchRecordsView(
      snapshot: makeSampleCompletedMatch(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeScore: 2,
        awayScore: 1,
        hasEvents: true))
      .frame(height: 420)
  }
}

#Preview("Records View - Empty Events") {
  NavigationStack {
    MatchRecordsView(
      snapshot: makeSampleCompletedMatch(
        homeTeam: "Manchester United",
        awayTeam: "Liverpool",
        homeScore: 3,
        awayScore: 2,
        hasEvents: false))
      .frame(height: 420)
  }
}
#endif
