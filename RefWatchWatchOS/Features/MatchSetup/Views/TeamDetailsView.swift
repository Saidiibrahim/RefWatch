import RefWatchCore
import SwiftUI
import WatchKit

struct TeamDetailsView: View {
  enum TeamType: Hashable {
    case home, away
  }

  let teamType: TeamType
  let matchViewModel: MatchViewModel
  let setupViewModel: MatchSetupViewModel
  let onGoalTypeSelected: (GoalDetails.GoalType) -> Void

  init(
    teamType: TeamType,
    matchViewModel: MatchViewModel,
    setupViewModel: MatchSetupViewModel,
    onGoalTypeSelected: @escaping (GoalDetails.GoalType) -> Void = { _ in })
  {
    self.teamType = teamType
    self.matchViewModel = matchViewModel
    self.setupViewModel = setupViewModel
    self.onGoalTypeSelected = onGoalTypeSelected
  }

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout
  @Environment(SettingsViewModel.self) private var settingsViewModel

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
    Text(self.teamDisplayName)
      .font(self.theme.typography.label.weight(.semibold))
      .foregroundStyle(self.theme.colors.textSecondary)
      .textCase(.uppercase)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
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
          WKInterfaceDevice.current().play(self.haptic(for: "square.fill"))
        },
        destination: {
          CardEventFlow(
            cardType: .yellow,
            team: self.teamType,
            matchViewModel: self.matchViewModel,
            setupViewModel: self.setupViewModel)
        }),
      AdaptiveEventGridItem(
        id: "red-card",
        icon: "square.fill",
        color: .red,
        label: "Red",
        onTap: {
          WKInterfaceDevice.current().play(self.haptic(for: "square.fill"))
        },
        destination: {
          CardEventFlow(
            cardType: .red,
            team: self.teamType,
            matchViewModel: self.matchViewModel,
            setupViewModel: self.setupViewModel)
        }),
      AdaptiveEventGridItem(
        id: "substitution",
        icon: "arrow.up.arrow.down",
        color: .blue,
        label: "Sub",
        onTap: {
          WKInterfaceDevice.current().play(self.haptic(for: "arrow.up.arrow.down"))
        },
        destination: {
          SubstitutionFlow(
            team: self.teamType,
            matchViewModel: self.matchViewModel,
            setupViewModel: self.setupViewModel,
            initialStep: self.initialSubstitutionStep)
        }),
      AdaptiveEventGridItem(
        id: "goal",
        icon: "soccerball",
        color: .green,
        label: "Goal",
        onTap: {
          WKInterfaceDevice.current().play(self.haptic(for: "soccerball"))
        },
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

  private var initialSubstitutionStep: SubstitutionFlow.SubstitutionStep {
    self.settingsViewModel.settings.substitutionOrderPlayerOffFirst ? .playerOff : .playerOn
  }

  private func haptic(for icon: String) -> WKHapticType {
    switch icon {
    case "square.fill":
      .notification
    case "arrow.up.arrow.down":
      .click
    case "soccerball":
      .click
    default:
      .notification
    }
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
  let setupViewModel = MatchSetupViewModel(matchViewModel: matchViewModel)

  return TeamDetailsView(teamType: .home, matchViewModel: matchViewModel, setupViewModel: setupViewModel)
    .environment(SettingsViewModel())
    .watchLayoutScale(WatchLayoutScale(category: .compact))
}

#Preview("Team Details – Ultra") {
  let matchViewModel = MatchViewModel(haptics: WatchHaptics())
  let setupViewModel = MatchSetupViewModel(matchViewModel: matchViewModel)

  return TeamDetailsView(teamType: .away, matchViewModel: matchViewModel, setupViewModel: setupViewModel)
    .environment(SettingsViewModel())
    .watchLayoutScale(WatchLayoutScale(category: .expanded))
}
