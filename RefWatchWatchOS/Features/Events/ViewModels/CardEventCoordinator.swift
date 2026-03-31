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
  var selectedPlayer: PlayerSelectionResult?
  var selectedOfficial: TeamOfficialSelectionResult?
  var selectedReason: MisconductReason?

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

  func handlePlayerSelection(_ selection: PlayerSelectionResult) {
    print("DEBUG: Selected player: \(String(describing: selection))")
    self.selectedPlayer = selection
    self.currentStep = .reason(isTeamOfficial: false)
  }

  func handleTeamOfficial(_ selection: TeamOfficialSelectionResult) {
    print("DEBUG: Selected team official: \(String(describing: selection))")
    self.selectedOfficial = selection
    print("DEBUG: Moving to reason selection with isTeamOfficial=true")
    self.currentStep = .reason(isTeamOfficial: true)
  }

  func handleReason(_ reason: MisconductReason) {
    print("DEBUG: Selected reason: \(reason.displayText)")
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
      "DEBUG: Recording card - Type: \(self.cardType), Reason: \(reason.displayText), " +
        "Player: \(String(describing: self.selectedPlayer)), " +
        "Official: \(String(describing: self.selectedOfficial))")

    // Use canonical card type directly
    let recipientType: CardRecipientType = self.selectedRecipient ?? .player
    let team: TeamSide = self.selectedTeam == .home ? .home : .away

    // Use new comprehensive recordCard method
    self.matchViewModel.recordCard(
      team: team,
      cardType: self.cardType,
      recipientType: recipientType,
      playerNumber: self.selectedPlayer?.number,
      playerName: self.selectedPlayer?.name,
      officialRole: self.selectedOfficial?.officialRole,
      officialRoleLabel: self.selectedOfficial?.officialRoleLabel,
      officialName: self.selectedOfficial?.officialName,
      reason: reason.displayText,
      reasonCode: reason.code,
      reasonTitle: reason.title)

    print("DEBUG: Successfully recorded card using new system")
  }

  /// Resets the coordinator to its initial state.
  /// Called when CardEventFlow appears to ensure fresh state on each presentation.
  func resetToInitialState() {
    self.currentStep = .recipient
    self.selectedRecipient = nil
    self.selectedPlayer = nil
    self.selectedOfficial = nil
    self.selectedReason = nil
  }

  var playerSelectionOptions: [PlayerSelectionOption] {
    guard let match = self.matchViewModel.currentMatch else { return [] }

    switch MatchParticipantSelectionResolver.resolveCardPlayers(
      match: match,
      team: self.teamSide,
      libraryTeams: self.matchViewModel.libraryTeams,
      events: self.matchViewModel.matchEvents)
    {
    case let .savedSheet(players), let .legacyLibrary(players):
      return players.map(PlayerSelectionOption.init(player:))
    case .manualOnly:
      return []
    }
  }

  var officialSelectionOptions: [TeamOfficialSelectionOption] {
    guard let match = self.matchViewModel.currentMatch else { return [] }

    switch MatchParticipantSelectionResolver.resolveCardOfficials(match: match, team: self.teamSide) {
    case let .savedSheet(officials):
      return officials.map(TeamOfficialSelectionOption.init(official:))
    case .manualOnly:
      return []
    }
  }

  private var teamSide: TeamSide {
    self.selectedTeam == .home ? .home : .away
  }
}
