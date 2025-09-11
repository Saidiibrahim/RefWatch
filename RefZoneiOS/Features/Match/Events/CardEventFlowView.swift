//
//  CardEventFlowView.swift
//  RefWatchiOS
//
//  Minimal card recording flow: recipient, optional player number/official role, and reason.
//

import SwiftUI
import RefWatchCore

struct CardEventFlowView: View {
    let matchViewModel: MatchViewModel

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
        "Violent conduct"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Team & Card") {
                    Picker("Team", selection: $team) {
                        Text(matchViewModel.homeTeamDisplayName).tag(TeamSide.home)
                        Text(matchViewModel.awayTeamDisplayName).tag(TeamSide.away)
                    }
                    .pickerStyle(.segmented)

                    Picker("Type", selection: $cardType) {
                        Text("Yellow").tag(CardDetails.CardType.yellow)
                        Text("Red").tag(CardDetails.CardType.red)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Recipient") {
                    Picker("Recipient", selection: $recipient) {
                        Text("Player").tag(CardRecipientType.player)
                        Text("Team Official").tag(CardRecipientType.teamOfficial)
                    }
                    .pickerStyle(.segmented)

                    if recipient == .player {
                        TextField("Player number", text: $playerNumber)
                            .keyboardType(.numberPad)
                    } else {
                        Picker("Official", selection: $officialRole) {
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
                    Picker("Preset", selection: $reason) {
                        ForEach(reasons, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Custom reason", text: $reason)
                }

                Section {
                    Button {
                        let num = Int(playerNumber)
                        matchViewModel.recordCard(
                            team: team,
                            cardType: cardType,
                            recipientType: recipient,
                            playerNumber: num,
                            officialRole: officialRole,
                            reason: reason
                        )
                        dismiss()
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
