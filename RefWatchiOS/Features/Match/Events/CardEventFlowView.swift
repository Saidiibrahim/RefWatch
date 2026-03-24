//
//  CardEventFlowView.swift
//  RefWatchiOS
//
//  Records card events using the same misconduct template catalog as watchOS.
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
  @State private var selectedReasonID: String = ""
  @State private var customReason: String = ""

  private var activeTemplate: MisconductTemplate {
    // iOS currently does not persist a per-user misconduct template selection.
    // Use the default template so iOS and watch reason catalogs stay consistent.
    MisconductTemplateCatalog.template(for: MisconductTemplateCatalog.defaultTemplateID)
  }

  private var reasons: [MisconductReason] {
    self.activeTemplate.reasons(for: self.cardType, recipient: self.recipient)
  }

  private var selectedReason: MisconductReason? {
    self.reasons.first(where: { $0.id == self.selectedReasonID })
  }

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
              Text("Manager").tag(TeamOfficialRole.manager)
              Text("Assistant Manager").tag(TeamOfficialRole.assistantManager)
              Text("Coach").tag(TeamOfficialRole.coach)
              Text("Physio").tag(TeamOfficialRole.physio)
              Text("Doctor").tag(TeamOfficialRole.doctor)
            }
          }
        }

        Section("Reason") {
          if self.reasons.isEmpty {
            Text("No reasons available for this card/recipient combination.")
              .foregroundStyle(.secondary)
          } else {
            Picker("Preset", selection: self.$selectedReasonID) {
              ForEach(self.reasons, id: \.id) { reason in
                Text(reason.displayText).tag(reason.id)
              }
            }
          }

          TextField("Custom reason (optional)", text: self.$customReason)
        }

        Section {
          Button {
            let trimmedCustom = self.customReason.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedReason = self.resolvedReason(customReason: trimmedCustom)

            self.matchViewModel.recordCard(
              team: self.team,
              cardType: self.cardType,
              recipientType: self.recipient,
              playerNumber: Int(self.playerNumber),
              officialRole: self.officialRole,
              reason: resolvedReason.reason,
              reasonCode: resolvedReason.code,
              reasonTitle: resolvedReason.title)

            self.onSaved?()
            self.dismiss()
          } label: {
            Label("Save Card", systemImage: "checkmark.circle.fill")
          }
          .tint(self.cardType == .yellow ? .yellow : .red)
        }
      }
      .navigationTitle("Card")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        self.ensureReasonSelectionIsValid()
      }
      .onChange(of: self.cardType) { _, _ in
        self.ensureReasonSelectionIsValid()
      }
      .onChange(of: self.recipient) { _, _ in
        self.ensureReasonSelectionIsValid()
      }
    }
  }
}

private extension CardEventFlowView {
  func ensureReasonSelectionIsValid() {
    if self.reasons.contains(where: { $0.id == self.selectedReasonID }) {
      return
    }
    self.selectedReasonID = self.reasons.first?.id ?? ""
  }

  func resolvedReason(customReason: String) -> (reason: String, code: String?, title: String?) {
    if customReason.isEmpty == false {
      return (reason: customReason, code: nil, title: customReason)
    }

    if let selectedReason {
      return (
        reason: selectedReason.displayText,
        code: selectedReason.code,
        title: selectedReason.title
      )
    }

    return (reason: "No reason supplied", code: nil, title: nil)
  }
}
