//
//  CardEventFlowView.swift
//  RefWatchiOS
//
//  Minimal card recording flow: recipient, optional player number/official role, and reason.
//

import RefWatchCore
import SwiftUI

struct CardEventFlowView: View {
  let matchViewModel: MatchViewModel
  var onSaved: (() -> Void)?

  @Environment(\.dismiss) private var dismiss

  @State private var team: TeamSide = .home
  @State private var cardType: CardDetails.CardType = .yellow
  @State private var recipient: CardRecipientType = .player
  @State private var playerNumber: String = ""
  @State private var officialRole: TeamOfficialRole = .coach
  @State private var reason: String = "Unsporting behaviour"

  private let reasons: [String] = [
    "Unsporting behaviour",
    "Dissent",
    "Persistent infringement",
    "Serious foul play",
    "Violent conduct",
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section("Team & Card") {
          Picker("Team", selection: self.$team) {
            Text(self.matchViewModel.homeTeamDisplayName).tag(TeamSide.home)
            Text(self.matchViewModel.awayTeamDisplayName).tag(TeamSide.away)
          }
          .pickerStyle(.segmented)

          Picker("Type", selection: self.$cardType) {
            Text("Yellow").tag(CardDetails.CardType.yellow)
            Text("Red").tag(CardDetails.CardType.red)
          }
          .pickerStyle(.segmented)
        }

        Section("Recipient") {
          Picker("Recipient", selection: self.$recipient) {
            Text("Player").tag(CardRecipientType.player)
            Text("Team Official").tag(CardRecipientType.teamOfficial)
          }
          .pickerStyle(.segmented)

          if self.recipient == .player {
            TextField("Player number", text: self.$playerNumber)
              .keyboardType(.numberPad)
          } else {
            Picker("Official", selection: self.$officialRole) {
              // Use roles defined in RefWatchCore TeamOfficialRole
              Text("Manager").tag(TeamOfficialRole.manager)
              Text("Assistant Manager").tag(TeamOfficialRole.assistantManager)
              Text("Coach").tag(TeamOfficialRole.coach)
              Text("Physio").tag(TeamOfficialRole.physio)
              Text("Doctor").tag(TeamOfficialRole.doctor)
            }
          }
        }

        Section("Reason") {
          Picker("Preset", selection: self.$reason) {
            ForEach(self.reasons, id: \.self) { Text($0).tag($0) }
          }
          TextField("Custom reason", text: self.$reason)
        }

        Section {
          Button {
            let num = Int(playerNumber)
            self.matchViewModel.recordCard(
              team: self.team,
              cardType: self.cardType,
              recipientType: self.recipient,
              playerNumber: num,
              officialRole: self.officialRole,
              reason: self.reason)
            self.onSaved?()
            self.dismiss()
          } label: {
            Label("Save Card", systemImage: "checkmark.circle.fill")
          }
        }
      }
      .navigationTitle("Card")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
