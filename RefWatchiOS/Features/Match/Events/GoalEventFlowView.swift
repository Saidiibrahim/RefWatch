//
//  GoalEventFlowView.swift
//  RefWatchiOS
//
//  Minimal goal recording flow: choose team, type, and optional player number.
//

import RefWatchCore
import SwiftUI

struct GoalEventFlowView: View {
  let matchViewModel: MatchViewModel
  var onSaved: (() -> Void)?

  @Environment(\.dismiss) private var dismiss

  @State private var team: TeamSide = .home
  @State private var type: GoalDetails.GoalType = .regular
  @State private var playerNumber: String = ""

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

        Section("Type") {
          Picker("Type", selection: self.$type) {
            Text("Regular").tag(GoalDetails.GoalType.regular)
            Text("Penalty").tag(GoalDetails.GoalType.penalty)
            Text("Own Goal").tag(GoalDetails.GoalType.ownGoal)
            Text("Free Kick").tag(GoalDetails.GoalType.freeKick)
          }
          .pickerStyle(.inline)
        }

        Section("Player") {
          TextField("Number (optional)", text: self.$playerNumber)
            .keyboardType(.numberPad)
        }

        Section {
          Button {
            let num = Int(playerNumber)
            self.matchViewModel.recordGoal(team: self.team, goalType: self.type, playerNumber: num)
            self.onSaved?()
            self.dismiss()
          } label: {
            Label("Save Goal", systemImage: "checkmark.circle.fill")
          }
        }
      }
      .navigationTitle("Goal")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
