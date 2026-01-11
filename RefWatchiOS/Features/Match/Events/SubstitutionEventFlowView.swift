//
//  SubstitutionEventFlowView.swift
//  RefWatchiOS
//
//  Minimal substitution flow: choose team and optional player numbers.
//

import RefWatchCore
import SwiftUI

struct SubstitutionEventFlowView: View {
  let matchViewModel: MatchViewModel
  var onSaved: (() -> Void)?

  @Environment(\.dismiss) private var dismiss

  @State private var team: TeamSide = .home
  @State private var playerOut: String = ""
  @State private var playerIn: String = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Team") {
          Picker("Team", selection: self.$team) {
            Text(self.matchViewModel.homeTeamDisplayName).tag(TeamSide.home)
            Text(self.matchViewModel.awayTeamDisplayName).tag(TeamSide.away)
          }
          .pickerStyle(.segmented)
        }

        Section("Players") {
          TextField("Player out (number)", text: self.$playerOut).keyboardType(.numberPad)
          TextField("Player in (number)", text: self.$playerIn).keyboardType(.numberPad)
        }

        Section {
          Button {
            let outNum = Int(playerOut)
            let inNum = Int(playerIn)
            self.matchViewModel.recordSubstitution(
              team: self.team,
              playerOut: outNum,
              playerIn: inNum,
              playerOutName: nil,
              playerInName: nil)
            self.onSaved?()
            self.dismiss()
          } label: {
            Label("Save Substitution", systemImage: "checkmark.circle.fill")
          }
        }
      }
      .navigationTitle("Substitution")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
