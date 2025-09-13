//
//  SubstitutionEventFlowView.swift
//  RefZoneiOS
//
//  Minimal substitution flow: choose team and optional player numbers.
//

import SwiftUI
import RefWatchCore

struct SubstitutionEventFlowView: View {
    let matchViewModel: MatchViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var team: TeamSide = .home
    @State private var playerOut: String = ""
    @State private var playerIn: String = ""

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

                Section("Players") {
                    TextField("Player out (number)", text: $playerOut).keyboardType(.numberPad)
                    TextField("Player in (number)", text: $playerIn).keyboardType(.numberPad)
                }

                Section {
                    Button {
                        let outNum = Int(playerOut)
                        let inNum = Int(playerIn)
                        matchViewModel.recordSubstitution(
                            team: team,
                            playerOut: outNum,
                            playerIn: inNum,
                            playerOutName: nil,
                            playerInName: nil
                        )
                        dismiss()
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
