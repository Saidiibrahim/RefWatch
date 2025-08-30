import SwiftUI
import Observation // Required for @Observable

// Manages the entire card event flow in one place
@Observable final class CardEventCoordinator: ObservableObject {
    enum Step: Equatable {
        case recipient
        case playerNumber(CardRecipientType)
        case teamOfficial
        case reason(isTeamOfficial: Bool)
        case complete
    }
    
    var currentStep: Step = .recipient
    var cardType: MatchEvent
    var selectedTeam: TeamDetailsView.TeamType
    var selectedRecipient: CardRecipientType?
    var selectedPlayerNumber: Int?
    var selectedOfficialRole: TeamOfficialRole?
    var selectedReason: String?
    
    private let matchViewModel: MatchViewModel
    private let setupViewModel: MatchSetupViewModel
    
    init(
        cardType: MatchEvent,
        team: TeamDetailsView.TeamType,
        matchViewModel: MatchViewModel,
        setupViewModel: MatchSetupViewModel
    ) {
        self.cardType = cardType
        self.selectedTeam = team
        self.matchViewModel = matchViewModel
        self.setupViewModel = setupViewModel
    }
    
    func handleRecipientSelection(_ recipient: CardRecipientType) {
        print("DEBUG: Selected recipient: \(recipient)")
        selectedRecipient = recipient
        switch recipient {
        case .player:
            print("DEBUG: Moving to player number input")
            currentStep = .playerNumber(recipient)
        case .teamOfficial:
            print("DEBUG: Moving to team official selection")
            currentStep = .teamOfficial
        }
    }
    
    func handlePlayerNumber(_ number: Int) {
        print("DEBUG: Selected player number: \(number)")
        selectedPlayerNumber = number
        currentStep = .reason(isTeamOfficial: false)
    }
    
    func handleTeamOfficial(_ role: TeamOfficialRole) {
        print("DEBUG: Selected team official role: \(role)")
        selectedOfficialRole = role
        print("DEBUG: Moving to reason selection with isTeamOfficial=true")
        currentStep = .reason(isTeamOfficial: true)
    }
    
    func handleReason(_ reason: String) {
        print("DEBUG: Selected reason: \(reason)")
        selectedReason = reason
        recordCard()
        print("DEBUG: Moving to complete state")
        currentStep = .complete
    }
    
    private func recordCard() {
        guard let reason = selectedReason else {
            print("DEBUG: Cannot record card - missing reason")
            return
        }
        
        print("DEBUG: Recording card - Type: \(cardType), Reason: \(reason), Player: \(String(describing: selectedPlayerNumber)), Official: \(String(describing: selectedOfficialRole))")
        
        // Map values to new comprehensive recording system
        let cardTypeEnum: CardDetails.CardType = cardType == .yellow ? .yellow : .red
        let recipientType: CardRecipientType = selectedRecipient ?? .player
        let team: TeamSide = selectedTeam == .home ? .home : .away
        
        // Use new comprehensive recordCard method
        matchViewModel.recordCard(
            team: team,
            cardType: cardTypeEnum,
            recipientType: recipientType,
            playerNumber: selectedPlayerNumber,
            officialRole: selectedOfficialRole,
            reason: reason
        )
        
        setupViewModel.setSelectedTab(1)
        print("DEBUG: Successfully recorded card using new system, navigating to middle screen...")
    }
} 