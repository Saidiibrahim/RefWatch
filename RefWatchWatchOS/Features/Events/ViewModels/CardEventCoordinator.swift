import Observation // Required for @Observable
import RefWatchCore
import SwiftUI

// Manages the entire card event flow in one place
@Observable @MainActor final class CardEventCoordinator {
  enum Step: Equatable {
    case recipient
    case playerNumber(CardRecipientType)
    case teamOfficial
    case reason(isTeamOfficial: Bool)
    case complete
  }

  var currentStep: Step = .recipient
  var cardType: CardDetails.CardType
  var selectedTeam: TeamDetailsView.TeamType
  var selectedRecipient: CardRecipientType?
  var selectedPlayerNumber: Int?
  var selectedOfficialRole: TeamOfficialRole?
  var selectedReason: String?

  private let matchViewModel: MatchViewModel

  init(
    cardType: CardDetails.CardType,
    team: TeamDetailsView.TeamType,
    matchViewModel: MatchViewModel)
  {
    self.cardType = cardType
    self.selectedTeam = team
    self.matchViewModel = matchViewModel
  }

  func handleRecipientSelection(_ recipient: CardRecipientType) {
    print("DEBUG: Selected recipient: \(recipient)")
    self.selectedRecipient = recipient
    switch recipient {
    case .player:
      print("DEBUG: Moving to player number input")
      self.currentStep = .playerNumber(recipient)
    case .teamOfficial:
      print("DEBUG: Moving to team official selection")
      self.currentStep = .teamOfficial
    }
  }

  func handlePlayerNumber(_ number: Int) {
    print("DEBUG: Selected player number: \(number)")
    self.selectedPlayerNumber = number
    self.currentStep = .reason(isTeamOfficial: false)
  }

  func handleTeamOfficial(_ role: TeamOfficialRole) {
    print("DEBUG: Selected team official role: \(role)")
    self.selectedOfficialRole = role
    print("DEBUG: Moving to reason selection with isTeamOfficial=true")
    self.currentStep = .reason(isTeamOfficial: true)
  }

  func handleReason(_ reason: String) {
    print("DEBUG: Selected reason: \(reason)")
    self.selectedReason = reason
    self.recordCard()
    print("DEBUG: Moving to complete state")
    self.currentStep = .complete
  }

  private func recordCard() {
    guard let reason = selectedReason else {
      print("DEBUG: Cannot record card - missing reason")
      return
    }

    print(
      "DEBUG: Recording card - Type: \(self.cardType), Reason: \(reason), " +
        "Player: \(String(describing: self.selectedPlayerNumber)), " +
        "Official: \(String(describing: self.selectedOfficialRole))")

    // Use canonical card type directly
    let recipientType: CardRecipientType = self.selectedRecipient ?? .player
    let team: TeamSide = self.selectedTeam == .home ? .home : .away

    // Use new comprehensive recordCard method
    self.matchViewModel.recordCard(
      team: team,
      cardType: self.cardType,
      recipientType: recipientType,
      playerNumber: self.selectedPlayerNumber,
      officialRole: self.selectedOfficialRole,
      reason: reason)

    print("DEBUG: Successfully recorded card using new system")
  }

  /// Resets the coordinator to its initial state.
  /// Called when CardEventFlow appears to ensure fresh state on each presentation.
  func resetToInitialState() {
    self.currentStep = .recipient
    self.selectedRecipient = nil
    self.selectedPlayerNumber = nil
    self.selectedOfficialRole = nil
    self.selectedReason = nil
  }
}
