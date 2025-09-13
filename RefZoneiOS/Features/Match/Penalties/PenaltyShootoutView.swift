//
//  PenaltyShootoutView.swift
//  RefZoneiOS
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
            VStack(spacing: AppTheme.Spacing.l) {
                Text("penalties_title").font(AppTheme.Typography.header)

                if matchViewModel.isPenaltyShootoutDecided, let winner = matchViewModel.penaltyWinner {
                    Text(String(format: NSLocalizedString("shootout_winner_format", comment: ""), (winner == .home ? matchViewModel.homeTeamDisplayName : matchViewModel.awayTeamDisplayName)))
                        .font(AppTheme.Typography.subheader)
                        .padding(AppTheme.Spacing.s)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: AppTheme.Corners.s).fill(.green.opacity(0.2)))
                } else if matchViewModel.isSuddenDeathActive {
                    Text("shootout_sudden_death")
                        .font(AppTheme.Typography.subheader)
                        .padding(AppTheme.Spacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: AppTheme.Corners.s).fill(.orange.opacity(0.2)))
                }

                HStack(spacing: AppTheme.Spacing.m) {
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
                    Label(LocalizedStringKey("shootout_end_cta"), systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!matchViewModel.isPenaltyShootoutDecided)
                .padding(.horizontal)
            }
            .navigationTitle("shootout_nav_title")
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
        VStack(spacing: AppTheme.Spacing.m - 2) {
            Text(title).font(AppTheme.Typography.header)
            Text("\(scored) / \(taken)").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: AppTheme.Spacing.xs) {
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
            HStack(spacing: AppTheme.Spacing.m - 2) {
                Button(action: onScore) {
                    Label(LocalizedStringKey("shootout_score"), systemImage: "checkmark.circle.fill")
                        .accessibilityLabel(Text("Record score for \(title)"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!active)

                Button(action: onMiss) {
                    Label(LocalizedStringKey("shootout_miss"), systemImage: "xmark.circle.fill")
                        .accessibilityLabel(Text("Record miss for \(title)"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!active)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: AppTheme.Corners.m).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Corners.m)
                .stroke(active ? .green : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    PenaltyShootoutView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}
