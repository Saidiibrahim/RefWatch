//
//  PenaltyShootoutView.swift
//  RefWatchiOS
//
//  Shootout UI with attempt recording and end gating.
//

import RefWatchCore
import SwiftUI

struct PenaltyShootoutView: View {
  let matchViewModel: MatchViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme

  private struct PanelState {
    let title: String
    let scored: Int
    let taken: Int
    let rounds: Int
    let results: [PenaltyAttemptDetails.Result]
    let isActive: Bool
  }

  private var homePanelState: PanelState {
    PanelState(
      title: self.matchViewModel.homeTeamDisplayName,
      scored: self.matchViewModel.homePenaltiesScored,
      taken: self.matchViewModel.homePenaltiesTaken,
      rounds: self.matchViewModel.penaltyRoundsVisible,
      results: self.matchViewModel.homePenaltyResults,
      isActive: self.matchViewModel.nextPenaltyTeam == .home
        && !self.matchViewModel.isPenaltyShootoutDecided)
  }

  private var awayPanelState: PanelState {
    PanelState(
      title: self.matchViewModel.awayTeamDisplayName,
      scored: self.matchViewModel.awayPenaltiesScored,
      taken: self.matchViewModel.awayPenaltiesTaken,
      rounds: self.matchViewModel.penaltyRoundsVisible,
      results: self.matchViewModel.awayPenaltyResults,
      isActive: self.matchViewModel.nextPenaltyTeam == .away
        && !self.matchViewModel.isPenaltyShootoutDecided)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: self.theme.spacing.l) {
        Text("penalties_title").font(self.theme.typography.heroTitle)

        if self.matchViewModel.isPenaltyShootoutDecided, let winner = matchViewModel.penaltyWinner {
          Text(
            String(
              format: NSLocalizedString("shootout_winner_format", comment: ""),
              winner == .home
                ? self.matchViewModel.homeTeamDisplayName
                : self.matchViewModel.awayTeamDisplayName))
            .font(self.theme.typography.heroSubtitle)
            .padding(self.theme.spacing.s)
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: self.theme.components.controlCornerRadius)
                .fill(self.theme.colors.matchPositive.opacity(0.2)))
        } else if self.matchViewModel.isSuddenDeathActive {
          Text("shootout_sudden_death")
            .font(self.theme.typography.heroSubtitle)
            .padding(self.theme.spacing.xs)
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: self.theme.components.controlCornerRadius)
                .fill(self.theme.colors.matchWarning.opacity(0.2)))
        }

        HStack(spacing: self.theme.spacing.m) {
          self.panel(
            self.homePanelState,
            onScore: { self.matchViewModel.recordPenaltyAttempt(team: .home, result: .scored) },
            onMiss: { self.matchViewModel.recordPenaltyAttempt(team: .home, result: .missed) })
          self.panel(
            self.awayPanelState,
            onScore: { self.matchViewModel.recordPenaltyAttempt(team: .away, result: .scored) },
            onMiss: { self.matchViewModel.recordPenaltyAttempt(team: .away, result: .missed) })
        }
        .padding(.horizontal)

        Spacer()

        Button {
          self.matchViewModel.endPenaltiesAndProceed()
          self.dismiss() // dismiss shootout; timer will present Full Time
        } label: {
          Label(LocalizedStringKey("shootout_end_cta"), systemImage: "flag.checkered")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!self.matchViewModel.isPenaltyShootoutDecided)
        .padding(.horizontal)
      }
      .navigationTitle("shootout_nav_title")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        self.matchViewModel.beginPenaltiesIfNeeded()
      }
    }
  }

  private func panel(
    _ state: PanelState,
    onScore: @escaping () -> Void,
    onMiss: @escaping () -> Void) -> some View
  {
    VStack(spacing: self.theme.spacing.m - 2) {
      Text(state.title).font(self.theme.typography.heroTitle)
      Text("\(state.scored) / \(state.taken)")
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)
      HStack(spacing: self.theme.spacing.xs) {
        ForEach(0..<state.rounds, id: \.self) { i in
          Group {
            if i < state.results.count {
              Circle()
                .fill(
                  state.results[i] == .scored
                    ? self.theme.colors.matchPositive
                    : self.theme.colors.matchCritical)
            } else {
              Circle().stroke(.secondary, lineWidth: 1)
            }
          }.frame(width: 8, height: 8)
        }
      }
      HStack(spacing: self.theme.spacing.m - 2) {
        Button(action: onScore) {
          Label(LocalizedStringKey("shootout_score"), systemImage: "checkmark.circle.fill")
            .accessibilityLabel(Text("Record score for \(state.title)"))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(self.theme.colors.matchPositive)
        .disabled(!state.isActive)

        Button(action: onMiss) {
          Label(LocalizedStringKey("shootout_miss"), systemImage: "xmark.circle.fill")
            .accessibilityLabel(Text("Record miss for \(state.title)"))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(self.theme.colors.matchCritical)
        .disabled(!state.isActive)
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(
      RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius)
        .fill(self.theme.colors.backgroundElevated))
    .overlay(
      RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius)
        .stroke(state.isActive ? self.theme.colors.matchPositive : .clear, lineWidth: 2))
  }
}

#Preview {
  PenaltyShootoutView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}
