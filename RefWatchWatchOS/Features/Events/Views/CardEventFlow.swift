import SwiftUI
import RefWatchCore

// View to handle the card event flow
struct CardEventFlow: View {
    @State private var coordinator: CardEventCoordinator
    let onComplete: () -> Void

    init(
        cardType: CardDetails.CardType,
        team: TeamDetailsView.TeamType,
        matchViewModel: MatchViewModel,
        onComplete: @escaping () -> Void
    ) {
        _coordinator = State(initialValue: CardEventCoordinator(
            cardType: cardType,
            team: team,
            matchViewModel: matchViewModel
        ))
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            switch coordinator.currentStep {
            case .recipient:
                CardRecipientSelectionView(
                    team: coordinator.selectedTeam,
                    cardType: coordinator.cardType,
                    onComplete: { recipient in
                        coordinator.handleRecipientSelection(recipient)
                    }
                )

            case .playerNumber:
                PlayerNumberInputView(
                    title: "Select Player",
                    selectionOptions: coordinator.playerSelectionOptions,
                    placeholder: "player #"
                ) { selection in
                    coordinator.handlePlayerSelection(selection)
                }

            case .teamOfficial:
                TeamOfficialSelectionView(
                    savedOfficials: coordinator.officialSelectionOptions
                ) { selection in
                    print("DEBUG: Team official selected, handling selection")
                    coordinator.handleTeamOfficial(selection)
                }

            case .reason(let isTeamOfficial):
                CardReasonSelectionView(
                    cardType: coordinator.cardType,
                    isTeamOfficial: isTeamOfficial
                ) { reason in
                    print("DEBUG: Selected reason in CardReasonSelectionView: \(reason.displayText)")
                    coordinator.handleReason(reason)
                }

            case .complete:
                EmptyView()
            }
        }
        .onAppear {
            coordinator.resetToInitialState()
        }
        .onChange(of: coordinator.currentStep) { _, newValue in
            print("DEBUG: Step changed to: \(newValue)")
            if case .complete = newValue {
                onComplete()
            }
        }
    }
}
