//
//  PenaltyShootoutView.swift
//  RefWatchiOS
//
//  Shootout UI with attempt recording and end gating.
//

import SwiftUI
import RefWatchCore

struct PenaltyShootoutView: View {
    let matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Penalties").font(.headline)

                if matchViewModel.isPenaltyShootoutDecided, let winner = matchViewModel.penaltyWinner {
                    Text("\(winner == .home ? matchViewModel.homeTeamDisplayName : matchViewModel.awayTeamDisplayName) win")
                        .font(.subheadline)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.green.opacity(0.2)))
                } else if matchViewModel.isSuddenDeathActive {
                    Text("Sudden Death")
                        .font(.subheadline)
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.orange.opacity(0.2)))
                }

                HStack(spacing: 12) {
                    panel(.home,
                          title: matchViewModel.homeTeamDisplayName,
                          scored: matchViewModel.homePenaltiesScored,
                          taken: matchViewModel.homePenaltiesTaken,
                          rounds: matchViewModel.penaltyRoundsVisible,
                          results: matchViewModel.homePenaltyResults,
                          active: matchViewModel.nextPenaltyTeam == .home && !matchViewModel.isPenaltyShootoutDecided,
                          onScore: { matchViewModel.recordPenaltyAttempt(team: .home, result: .scored) },
                          onMiss: { matchViewModel.recordPenaltyAttempt(team: .home, result: .missed) })
                    panel(.away,
                          title: matchViewModel.awayTeamDisplayName,
                          scored: matchViewModel.awayPenaltiesScored,
                          taken: matchViewModel.awayPenaltiesTaken,
                          rounds: matchViewModel.penaltyRoundsVisible,
                          results: matchViewModel.awayPenaltyResults,
                          active: matchViewModel.nextPenaltyTeam == .away && !matchViewModel.isPenaltyShootoutDecided,
                          onScore: { matchViewModel.recordPenaltyAttempt(team: .away, result: .scored) },
                          onMiss: { matchViewModel.recordPenaltyAttempt(team: .away, result: .missed) })
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    matchViewModel.endPenaltiesAndProceed()
                    dismiss() // dismiss shootout; timer will present Full Time
                } label: {
                    Label("End Shootout", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!matchViewModel.isPenaltyShootoutDecided)
                .padding(.horizontal)
            }
            .navigationTitle("Shootout")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                matchViewModel.beginPenaltiesIfNeeded()
            }
        }
    }

    private func panel(_ side: TeamSide,
                       title: String,
                       scored: Int,
                       taken: Int,
                       rounds: Int,
                       results: [PenaltyAttemptDetails.Result],
                       active: Bool,
                       onScore: @escaping () -> Void,
                       onMiss: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.headline)
            Text("\(scored) / \(taken)").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(0..<rounds, id: \.self) { i in
                    Group {
                        if i < results.count {
                            Circle().fill(results[i] == .scored ? .green : .red)
                        } else {
                            Circle().stroke(.secondary, lineWidth: 1)
                        }
                    }.frame(width: 8, height: 8)
                }
            }
            HStack(spacing: 10) {
                Button(action: onScore) {
                    Label("Score", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!active)

                Button(action: onMiss) {
                    Label("Miss", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!active)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(active ? .green : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    PenaltyShootoutView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}

