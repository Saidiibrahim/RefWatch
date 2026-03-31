// MatchSetupView.swift
// Implements the three-screen swipeable layout:
// Left: Home team details
// Middle: Match start screen
// Right: Away team details

import SwiftUI
import RefWatchCore

struct MatchSetupView: View {
    @State private var viewModel: MatchSetupViewModel
    let lifecycle: MatchLifecycleCoordinator
    let isLifecycleAlertPresented: Bool
    private let liveActivityPublisher: any MatchLiveActivityPublishing
    private let commandHandler: LiveActivityCommandHandler
    @State private var goalInputContext: GoalInputContext?
    @State private var cardEventContext: CardEventContext?
    @State private var substitutionContext: SubstitutionContext?

    @MainActor
    init(
        matchViewModel: MatchViewModel,
        lifecycle: MatchLifecycleCoordinator,
        isLifecycleAlertPresented: Bool = false,
        liveActivityPublisher: (any MatchLiveActivityPublishing)? = nil,
        commandHandler: LiveActivityCommandHandler? = nil
    ) {
        _viewModel = State(initialValue: MatchSetupViewModel(matchViewModel: matchViewModel))
        self.lifecycle = lifecycle
        self.isLifecycleAlertPresented = isLifecycleAlertPresented
        self.liveActivityPublisher = liveActivityPublisher ?? LiveActivityStatePublisher(reloadKind: "RefWatchWidgets")
        self.commandHandler = commandHandler ?? LiveActivityCommandHandler()
    }

    var body: some View {
        TabView(selection: .init(
            get: { viewModel.selectedTab },
            set: { viewModel.setSelectedTab($0) }
        )) {
            // Home Team Details
            TeamDetailsView(
                teamType: .home,
                matchViewModel: viewModel.matchViewModel,
                onGoalTypeSelected: { goalType in
                    goalInputContext = GoalInputContext(team: .home, goalType: goalType)
                },
                onCardSelected: { cardType in
                    cardEventContext = CardEventContext(team: .home, cardType: cardType)
                },
                onSubstitutionSelected: {
                    substitutionContext = SubstitutionContext(team: .home)
                }
            )
            .tag(0)

            // Timer View (Middle)
            TimerView(
                model: viewModel.matchViewModel,
                lifecycle: lifecycle,
                isLifecycleAlertPresented: self.isLifecycleAlertPresented,
                liveActivityPublisher: self.liveActivityPublisher,
                commandHandler: self.commandHandler
            )
                .tag(1)

            // Away Team Details
            TeamDetailsView(
                teamType: .away,
                matchViewModel: viewModel.matchViewModel,
                onGoalTypeSelected: { goalType in
                    goalInputContext = GoalInputContext(team: .away, goalType: goalType)
                },
                onCardSelected: { cardType in
                    cardEventContext = CardEventContext(team: .away, cardType: cardType)
                },
                onSubstitutionSelected: {
                    substitutionContext = SubstitutionContext(team: .away)
                }
            )
            .tag(2)
        }
        .tabViewStyle(.page)
        .navigationDestination(item: $goalInputContext) { context in
            PlayerNumberInputView(
                title: "Goal Scorer",
                selectionOptions: self.goalSelectionOptions(for: context.team),
                placeholder: "goal scorer",
                onComplete: { selection in
                    recordGoal(teamType: context.team, goalType: context.goalType, playerSelection: selection)
                    goalInputContext = nil
                }
            )
        }
        .navigationDestination(item: $cardEventContext) { context in
            CardEventFlow(
                cardType: context.cardType,
                team: context.team,
                matchViewModel: viewModel.matchViewModel,
                onComplete: {
                    cardEventContext = nil
                    viewModel.setSelectedTab(1)
                }
            )
        }
        .navigationDestination(item: $substitutionContext) { context in
            SubstitutionFlow(
                team: context.team,
                matchViewModel: viewModel.matchViewModel,
                onComplete: {
                    substitutionContext = nil
                    viewModel.setSelectedTab(1)
                }
            )
        }
        .onChange(of: self.isLifecycleAlertPresented) { _, isPresented in
            if isPresented {
                self.viewModel.setSelectedTab(1)
            }
        }
    }

    private func recordGoal(
        teamType: TeamDetailsView.TeamType,
        goalType: GoalDetails.GoalType,
        playerSelection: PlayerSelectionResult)
    {
        print(
            "DEBUG: Recording goal - Type: \(goalType.rawValue), Player: \(String(describing: playerSelection)), Team: \(teamType)")
        let scoringTeam: TeamSide
        switch goalType {
        case .regular, .freeKick, .penalty:
            scoringTeam = teamType == .home ? .home : .away
        case .ownGoal:
            // Own goal: credit the opposite team of the side initiating this flow
            scoringTeam = teamType == .home ? .away : .home
        }
        viewModel.matchViewModel.recordGoal(
            team: scoringTeam,
            goalType: goalType,
            playerNumber: playerSelection.number,
            playerName: playerSelection.name
        )
        print("DEBUG: Goal recording completed successfully using new system")
        print("DEBUG: Navigating to middle screen...")
        viewModel.setSelectedTab(1)
    }

    private func goalSelectionOptions(for team: TeamDetailsView.TeamType) -> [PlayerSelectionOption] {
        guard let match = self.viewModel.matchViewModel.currentMatch else { return [] }

        switch MatchParticipantSelectionResolver.resolve(
            match: match,
            team: team == .home ? .home : .away,
            libraryTeams: self.viewModel.matchViewModel.libraryTeams,
            events: self.viewModel.matchViewModel.matchEvents)
        {
        case let .frozenSheet(lineup):
            return lineup.onField.map(PlayerSelectionOption.init(entry:))
        case let .legacyLibrary(players):
            return players.map(PlayerSelectionOption.init(player:))
        case .manualOnly:
            return []
        }
    }
}

#Preview("Match Setup - Alert Presented") {
    MatchSetupView(
        matchViewModel: MatchViewModel.previewExpiredBoundary(),
        lifecycle: MatchLifecycleCoordinator(),
        isLifecycleAlertPresented: true,
        liveActivityPublisher: WatchPreviewSupport.makeLiveActivityPublisher(),
        commandHandler: WatchPreviewSupport.makeCommandHandler()
    )
    .defaultAppStorage(WatchPreviewSupport.makeDefaults(suiteName: "RefWatch.watchPreview.setup.alert"))
    .watchPreviewChrome()
}

// MARK: - Navigation Helpers

private struct GoalInputContext: Identifiable, Hashable {
    let id: String
    let team: TeamDetailsView.TeamType
    let goalType: GoalDetails.GoalType

    init(team: TeamDetailsView.TeamType, goalType: GoalDetails.GoalType) {
        self.team = team
        self.goalType = goalType
        let teamId = team == .home ? "home" : "away"
        self.id = "\(teamId)-\(goalType.rawValue)"
    }
}

private struct CardEventContext: Identifiable, Hashable {
    let id = UUID()
    let team: TeamDetailsView.TeamType
    let cardType: CardDetails.CardType
}

private struct SubstitutionContext: Identifiable, Hashable {
    let id = UUID()
    let team: TeamDetailsView.TeamType
}
