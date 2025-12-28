//
//  GoalEventFlowView.swift
//  RefWatchiOS
//
//  Minimal goal recording flow: choose team, type, and optional player number.
//

import SwiftUI
import RefWatchCore

struct GoalEventFlowView: View {
    let matchViewModel: MatchViewModel
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var team: TeamSide = .home
    @State private var type: GoalDetails.GoalType = .regular
    @State private var playerNumber: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Team") {
                    Picker("Team", selection: $team) {
                        Text(matchViewModel.homeTeamDisplayName).tag(TeamSide.home)
                        Text(matchViewModel.awayTeamDisplayName).tag(TeamSide.away)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        Text("Regular").tag(GoalDetails.GoalType.regular)
                        Text("Penalty").tag(GoalDetails.GoalType.penalty)
                        Text("Own Goal").tag(GoalDetails.GoalType.ownGoal)
                        Text("Free Kick").tag(GoalDetails.GoalType.freeKick)
                    }
                    .pickerStyle(.inline)
                }

                Section("Player") {
                    TextField("Number (optional)", text: $playerNumber)
                        .keyboardType(.numberPad)
                }

                Section {
                    Button {
                        let num = Int(playerNumber)
                        matchViewModel.recordGoal(team: team, goalType: type, playerNumber: num)
                        onSaved?()
                        dismiss()
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
