import RefWatchCore
import SwiftUI

struct TeamDetailsView: View {
  enum TeamType: Hashable {
    case home, away
  }

  let teamType: TeamType
  let matchViewModel: MatchViewModel
  let onGoalTypeSelected: (GoalDetails.GoalType) -> Void
  let onCardSelected: (CardDetails.CardType) -> Void
  let onSubstitutionSelected: () -> Void

  init(
    teamType: TeamType,
    matchViewModel: MatchViewModel,
    onGoalTypeSelected: @escaping (GoalDetails.GoalType) -> Void = { _ in },
    onCardSelected: @escaping (CardDetails.CardType) -> Void = { _ in },
    onSubstitutionSelected: @escaping () -> Void = {})
  {
    self.teamType = teamType
    self.matchViewModel = matchViewModel
    self.onGoalTypeSelected = onGoalTypeSelected
    self.onCardSelected = onCardSelected
    self.onSubstitutionSelected = onSubstitutionSelected
  }

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    VStack(spacing: self.theme.spacing.m) {
      self.header

      AdaptiveEventGrid(items: self.eventGridItems)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, self.theme.spacing.m)
    .padding(.top, self.theme.spacing.s)
    .padding(.bottom, self.layout.safeAreaBottomPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private var header: some View {
    TeamNameAbbreviationText(
      name: self.teamDisplayName,
      font: self.theme.typography.label.weight(.semibold),
      color: self.theme.colors.textSecondary,
      alignment: .leading
    )
    .textCase(.uppercase)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, self.theme.spacing.xs)
    .accessibilityLabel(self.teamDisplayNameAccessibility)
  }

  private var eventGridItems: [AdaptiveEventGridItem] {
    [
      AdaptiveEventGridItem(
        id: "yellow-card",
        icon: "square.fill",
        color: .yellow,
        label: "Yellow",
        onTap: {
          self.onCardSelected(.yellow)
        }),
      AdaptiveEventGridItem(
        id: "red-card",
        icon: "square.fill",
        color: .red,
        label: "Red",
        onTap: {
          self.onCardSelected(.red)
        }),
      AdaptiveEventGridItem(
        id: "substitution",
        icon: "arrow.up.arrow.down",
        color: .blue,
        label: "Sub",
        onTap: {
          self.onSubstitutionSelected()
        }),
      AdaptiveEventGridItem(
        id: "goal",
        icon: "soccerball",
        color: .green,
        label: "Goal",
        onTap: {},
        destination: {
          GoalTypeSelectionView(
            team: self.teamType,
            teamDisplayName: self.teamDisplayName)
          { goalType in
            self.onGoalTypeSelected(goalType)
          }
        }),
    ]
  }

  private var teamDisplayName: String {
    let rawName = self.teamType == .home ? self.matchViewModel.homeTeamDisplayName : self.matchViewModel
      .awayTeamDisplayName
    if rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return self.teamType == .home ? "Home" : "Away"
    }
    return rawName
  }

  private var teamDisplayNameAccessibility: String {
    let role = self.teamType == .home ? "home team" : "away team"
    return "\(self.teamDisplayName), \(role)"
  }
}

#Preview("Team Details – 41mm") {
  let matchViewModel = MatchViewModel(haptics: WatchHaptics())

  return TeamDetailsView(teamType: .home, matchViewModel: matchViewModel)
    .environment(SettingsViewModel())
    .watchLayoutScale(WatchLayoutScale(category: .compact))
}

#Preview("Team Details – Ultra") {
  let matchViewModel = MatchViewModel(haptics: WatchHaptics())

  return TeamDetailsView(teamType: .away, matchViewModel: matchViewModel)
    .environment(SettingsViewModel())
    .watchLayoutScale(WatchLayoutScale(category: .expanded))
}
