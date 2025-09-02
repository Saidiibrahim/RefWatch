//
//  PenaltyShootoutView.swift
//  RefWatch Watch App
//
//  Description: Penalty shootout flow with attempts and tallies for each team.
//

import SwiftUI
import WatchKit

struct PenaltyShootoutView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 2) {
                Text(formattedCurrentTime)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Text("Penalties")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            if matchViewModel.isPenaltyShootoutDecided, let winner = matchViewModel.penaltyWinner {
                Text("\(winner == .home ? matchViewModel.homeTeamDisplayName : matchViewModel.awayTeamDisplayName) win")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(8)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color.green)
                    )
                    .padding(.horizontal)
            } else if matchViewModel.isSuddenDeathActive {
                Text("Sudden Death")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(6)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color.orange)
                    )
                    .padding(.horizontal)
            }

            // Tallies
            HStack(spacing: 12) {
                PenaltyTeamPanel(
                    side: .home,
                    title: matchViewModel.homeTeamDisplayName,
                    scored: matchViewModel.homePenaltiesScored,
                    taken: matchViewModel.homePenaltiesTaken,
                    rounds: matchViewModel.penaltyRoundsVisible,
                    results: matchViewModel.homePenaltyResults,
                    isActive: matchViewModel.nextPenaltyTeam == .home && !matchViewModel.isPenaltyShootoutDecided,
                    isDisabled: matchViewModel.isPenaltyShootoutDecided,
                    onScore: { matchViewModel.recordPenaltyAttempt(team: .home, result: .scored) },
                    onMiss: { matchViewModel.recordPenaltyAttempt(team: .home, result: .missed) }
                )

                PenaltyTeamPanel(
                    side: .away,
                    title: matchViewModel.awayTeamDisplayName,
                    scored: matchViewModel.awayPenaltiesScored,
                    taken: matchViewModel.awayPenaltiesTaken,
                    rounds: matchViewModel.penaltyRoundsVisible,
                    results: matchViewModel.awayPenaltyResults,
                    isActive: matchViewModel.nextPenaltyTeam == .away && !matchViewModel.isPenaltyShootoutDecided,
                    isDisabled: matchViewModel.isPenaltyShootoutDecided,
                    onScore: { matchViewModel.recordPenaltyAttempt(team: .away, result: .scored) },
                    onMiss: { matchViewModel.recordPenaltyAttempt(team: .away, result: .missed) }
                )
            }
            .padding(.horizontal)

            Spacer()
        }
        .onAppear {
            // Ensure we mark penalties started once (idempotent)
            matchViewModel.beginPenaltiesIfNeeded()
        }
        // Bottom action
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                WKInterfaceDevice.current().play(.success)
                #if DEBUG
                print("DEBUG: PenaltyShootoutView: End Shootout tapped (decided=\(matchViewModel.isPenaltyShootoutDecided))")
                #endif
                matchViewModel.endPenaltiesAndProceed()
                #if DEBUG
                print("DEBUG: PenaltyShootoutView: endPenaltiesAndProceed -> isFullTime=\(matchViewModel.isFullTime)")
                #endif
                lifecycle.goToFinished()
            }) {
                Text("End Shootout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(matchViewModel.isPenaltyShootoutDecided ? Color.green : Color.gray)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("endShootoutButton")
            .disabled(!matchViewModel.isPenaltyShootoutDecided)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        // First-kicker prompt handled at ContentView level before routing
    }

    private var formattedCurrentTime: String {
        DateFormatter.watchShortTime.string(from: Date())
    }
}

private struct PenaltyTeamPanel: View {
    let side: TeamSide
    let title: String
    let scored: Int
    let taken: Int
    let rounds: Int
    let results: [PenaltyAttemptDetails.Result]
    let isActive: Bool
    let isDisabled: Bool
    let onScore: () -> Void
    let onMiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("\(scored) / \(taken)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.green)

            // Per-round dots (first 5, then grow for sudden death)
            HStack(spacing: 6) {
                ForEach(0..<rounds, id: \.self) { idx in
                    Group {
                        if idx < results.count {
                            if results[idx] == .scored {
                                Circle().fill(Color.green)
                            } else {
                                Circle().fill(Color.red)
                            }
                        } else {
                            Circle().stroke(Color.white.opacity(0.6), lineWidth: 1)
                        }
                    }
                    .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: 8) {
                Button(action: onScore) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.green))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(side == .home ? "homeScorePenaltyBtn" : "awayScorePenaltyBtn")
                .disabled(!isActive || isDisabled)

                Button(action: onMiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(side == .home ? "homeMissPenaltyBtn" : "awayMissPenaltyBtn")
                .disabled(!isActive || isDisabled)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// FirstKickerPickerView removed; replaced by dedicated PenaltyFirstKickerView screen

#Preview {
    PenaltyShootoutView(matchViewModel: MatchViewModel(), lifecycle: MatchLifecycleCoordinator())
}
