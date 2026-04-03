//
//  MatchRecordsView.swift
//  RefWatchWatchOS
//
//  Three-page completed-match records confirmation flow.
//

import RefWatchCore
import SwiftUI

struct MatchRecordsView: View {
  let snapshot: CompletedMatch
  @State private var selectedPage: Int

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
    .tabViewStyle(.page)
  }
}

#if DEBUG
#Preview("Records View - Standard") {
  NavigationStack {
    MatchRecordsView(
      snapshot: makeSampleCompletedMatch(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeScore: 2,
        awayScore: 1,
        hasEvents: true))
  }
  .watchPreviewChrome()
}

#Preview("Records View - Compact") {
  NavigationStack {
    MatchRecordsView(
      snapshot: makeSampleCompletedMatch(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeScore: 2,
        awayScore: 1,
        hasEvents: true))
  }
  .watchPreviewChrome(layout: WatchPreviewSupport.compactLayout)
}
#endif
