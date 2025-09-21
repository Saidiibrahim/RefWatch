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
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                Text("penalties_title").font(theme.typography.heroTitle)

                if matchViewModel.isPenaltyShootoutDecided, let winner = matchViewModel.penaltyWinner {
                    Text(String(format: NSLocalizedString("shootout_winner_format", comment: ""), (winner == .home ? matchViewModel.homeTeamDisplayName : matchViewModel.awayTeamDisplayName)))
                        .font(theme.typography.heroSubtitle)
                        .padding(theme.spacing.s)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: theme.components.controlCornerRadius)
                                .fill(theme.colors.matchPositive.opacity(0.2))
                        )
                } else if matchViewModel.isSuddenDeathActive {
                    Text("shootout_sudden_death")
                        .font(theme.typography.heroSubtitle)
                        .padding(theme.spacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: theme.components.controlCornerRadius)
                                .fill(theme.colors.matchWarning.opacity(0.2))
                        )
                }

                HStack(spacing: theme.spacing.m) {
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
        VStack(spacing: theme.spacing.m - 2) {
            Text(title).font(theme.typography.heroTitle)
            Text("\(scored) / \(taken)")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
            HStack(spacing: theme.spacing.xs) {
                ForEach(0..<rounds, id: \.self) { i in
                    Group {
                        if i < results.count {
                            Circle().fill(results[i] == .scored ? theme.colors.matchPositive : theme.colors.matchCritical)
                        } else {
                            Circle().stroke(.secondary, lineWidth: 1)
                        }
                    }.frame(width: 8, height: 8)
                }
            }
            HStack(spacing: theme.spacing.m - 2) {
                Button(action: onScore) {
                    Label(LocalizedStringKey("shootout_score"), systemImage: "checkmark.circle.fill")
                        .accessibilityLabel(Text("Record score for \(title)"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors.matchPositive)
                .disabled(!active)

                Button(action: onMiss) {
                    Label(LocalizedStringKey("shootout_miss"), systemImage: "xmark.circle.fill")
                        .accessibilityLabel(Text("Record miss for \(title)"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.colors.matchCritical)
                .disabled(!active)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                .fill(theme.colors.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                .stroke(active ? theme.colors.matchPositive : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    PenaltyShootoutView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}
