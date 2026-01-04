//
//  MatchKickoffView.swift
//  RefWatchiOS
//
//  Kickoff selection view for second half and extra time phases.
//

import RefWatchCore
import SwiftUI

struct MatchKickoffView: View {
  enum Phase {
    case firstHalf
    case secondHalf
    case extraTimeFirst
    case extraTimeSecond
  }

  let matchViewModel: MatchViewModel
  let phase: Phase
  let defaultSelected: TeamSide?
  let onConfirmStart: (() -> Void)?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme
  @State private var selected: TeamSide?

  init(
    matchViewModel: MatchViewModel,
    phase: Phase,
    defaultSelected: TeamSide? = nil,
    onConfirmStart: (() -> Void)? = nil)
  {
    self.matchViewModel = matchViewModel
    self.phase = phase
    self.defaultSelected = defaultSelected
    self.onConfirmStart = onConfirmStart
    _selected = State(initialValue: defaultSelected)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: self.theme.spacing.l) {
        VStack(spacing: self.theme.spacing.s - 2) {
          Text(self.headerTitle)
            .font(self.theme.typography.heroTitle)
          Text(self.durationLabel)
            .font(self.theme.typography.heroSubtitle)
            .foregroundStyle(self.theme.colors.textSecondary)
        }

        HStack(spacing: self.theme.spacing.m) {
          self.teamButton(
            .home,
            name: self.matchViewModel.homeTeamDisplayName,
            score: self.matchViewModel.currentMatch?.homeScore ?? 0)
          self.teamButton(
            .away,
            name: self.matchViewModel.awayTeamDisplayName,
            score: self.matchViewModel.currentMatch?.awayScore ?? 0)
        }
        .padding(.horizontal)

        Spacer()

        Button {
          guard let s = selected else { return }
          switch self.phase {
          case .firstHalf:
            self.matchViewModel.setKickingTeam(s == .home)
            self.matchViewModel.startMatch()
            self.onConfirmStart?()
          case .secondHalf:
            self.matchViewModel.setKickingTeam(s == .home)
            self.matchViewModel.startSecondHalfManually()
          case .extraTimeFirst:
            self.matchViewModel.setKickingTeamET1(s == .home)
            self.matchViewModel.startExtraTimeFirstHalfManually()
          case .extraTimeSecond:
            self.matchViewModel.startExtraTimeSecondHalfManually()
          }
          self.dismiss()
        } label: {
          Label(LocalizedStringKey("kickoff_start_cta"), systemImage: "checkmark.circle.fill")
            .font(self.theme.typography.heroTitle)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(self.selected == nil && self.phase != .extraTimeSecond)
        .padding(.horizontal)
      }
    }
    .onAppear {
      // Ensure defaults are set on appear (covers ET second half default override case)
      if self.selected == nil, let d = defaultSelected { self.selected = d }
    }
  }

  private var headerTitle: String {
    switch self.phase {
    case .firstHalf: String(localized: "kickoff_header_first")
    case .secondHalf: String(localized: "kickoff_header_second")
    case .extraTimeFirst: String(localized: "kickoff_header_et1")
    case .extraTimeSecond: String(localized: "kickoff_header_et2")
    }
  }

  private var durationLabel: String {
    guard let m = matchViewModel.currentMatch else { return "--:--" }
    if case .extraTimeFirst = self.phase { return Self.format(seconds: Int(m.extraTimeHalfLength)) }
    if case .extraTimeSecond = self.phase { return Self.format(seconds: Int(m.extraTimeHalfLength)) }
    let per = m.duration / TimeInterval(max(1, m.numberOfPeriods))
    return Self.format(seconds: Int(per))
  }

  private func teamButton(_ side: TeamSide, name: String, score: Int) -> some View {
    Button {
      self.selected = side
    } label: {
      VStack(spacing: self.theme.spacing.s) {
        Text(name).font(self.theme.typography.heroSubtitle)
        Text("\(score)")
          .font(self.theme.typography.timerSecondary)
          .monospacedDigit()
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(
        RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius)
          .fill((self.selected == side) ? self.theme.colors.matchPositive : self.theme.colors.backgroundElevated))
      .foregroundStyle((self.selected == side) ? Color.white : self.theme.colors.textPrimary)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(side == .home ? "homeTeamButton" : "awayTeamButton")
    .accessibilityLabel(
      Text(
        String(
          format: NSLocalizedString("kickoff_select_team_accessibility", comment: ""),
          name)))
  }

  private static func format(seconds: Int) -> String {
    let mm = seconds / 60
    let ss = seconds % 60
    return String(format: "%02d:%02d", mm, ss)
  }
}

#Preview {
  let vm = MatchViewModel(haptics: NoopHaptics())
  vm.newMatch = Match(homeTeam: "Home", awayTeam: "Away")
  vm.createMatch()
  return MatchKickoffView(matchViewModel: vm, phase: .secondHalf, defaultSelected: .home)
}
