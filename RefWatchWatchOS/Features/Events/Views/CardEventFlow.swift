import SwiftUI
import RefWatchCore

// New view to handle the card event flow
struct CardEventFlow: View {
    @StateObject private var coordinator: CardEventCoordinator
    @Environment(\.dismiss) private var dismiss
    
    init(
        cardType: CardDetails.CardType,
        team: TeamDetailsView.TeamType,
        matchViewModel: MatchViewModel,
        setupViewModel: MatchSetupViewModel
    ) {
        _coordinator = StateObject(wrappedValue: CardEventCoordinator(
            cardType: cardType,
            team: team,
            matchViewModel: matchViewModel,
            setupViewModel: setupViewModel
        ))
    }
    
    var body: some View {
        NavigationStack {
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
                        team: coordinator.selectedTeam,
                        goalType: nil,
                        cardType: coordinator.cardType,
                        context: "player #"
                    ) { number in
                        coordinator.handlePlayerNumber(number)
                    }
                    
                case .teamOfficial:
                    TeamOfficialSelectionView(
                        team: coordinator.selectedTeam
                    ) { role in
                        print("DEBUG: Team official selected, handling role")
                        coordinator.handleTeamOfficial(role)
                    }
                    
                case .reason(let isTeamOfficial):
                    CardReasonSelectionView(
                        cardType: coordinator.cardType,
                        isTeamOfficial: isTeamOfficial
                    ) { reason in
                        print("DEBUG: Selected reason in CardReasonSelectionView: \(reason)")
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
                    dismiss()
                }
            }
        }
    }
} 
