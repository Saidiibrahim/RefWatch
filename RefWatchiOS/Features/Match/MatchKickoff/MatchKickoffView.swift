//
//  MatchKickoffView.swift
//  RefWatchiOS
//
//  Kickoff selection view for second half and extra time phases.
//

import SwiftUI
import RefWatchCore

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
    @State private var selected: TeamSide?

    init(matchViewModel: MatchViewModel, phase: Phase, defaultSelected: TeamSide? = nil, onConfirmStart: (() -> Void)? = nil) {
        self.matchViewModel = matchViewModel
        self.phase = phase
        self.defaultSelected = defaultSelected
        self.onConfirmStart = onConfirmStart
        _selected = State(initialValue: defaultSelected)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.l) {
                VStack(spacing: AppTheme.Spacing.s - 2) {
                    Text(headerTitle)
                        .font(AppTheme.Typography.header)
                    Text(durationLabel)
                        .font(AppTheme.Typography.subheader)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppTheme.Spacing.m) {
                    teamButton(.home, name: matchViewModel.homeTeamDisplayName,
                               score: matchViewModel.currentMatch?.homeScore ?? 0)
                    teamButton(.away, name: matchViewModel.awayTeamDisplayName,
                               score: matchViewModel.currentMatch?.awayScore ?? 0)
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    guard let s = selected else { return }
                    switch phase {
                    case .firstHalf:
                        matchViewModel.setKickingTeam(s == .home)
                        matchViewModel.startMatch()
                        onConfirmStart?()
                    case .secondHalf:
                        matchViewModel.setKickingTeam(s == .home)
                        matchViewModel.startSecondHalfManually()
                    case .extraTimeFirst:
                        matchViewModel.setKickingTeamET1(s == .home)
                        matchViewModel.startExtraTimeFirstHalfManually()
                    case .extraTimeSecond:
                        matchViewModel.startExtraTimeSecondHalfManually()
                    }
                    dismiss()
                } label: {
                    Label(LocalizedStringKey("kickoff_start_cta"), systemImage: "checkmark.circle.fill")
                        .font(AppTheme.Typography.header)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected == nil && phase != .extraTimeSecond)
                .padding(.horizontal)
            }
            .navigationTitle("kickoff_title")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Ensure defaults are set on appear (covers ET second half default override case)
            if selected == nil, let d = defaultSelected { selected = d }
        }
    }

    private var headerTitle: String {
        switch phase {
        case .firstHalf: return String(localized: "kickoff_header_first")
        case .secondHalf: return String(localized: "kickoff_header_second")
        case .extraTimeFirst: return String(localized: "kickoff_header_et1")
        case .extraTimeSecond: return String(localized: "kickoff_header_et2")
        }
    }

    private var durationLabel: String {
        guard let m = matchViewModel.currentMatch else { return "--:--" }
        if case .extraTimeFirst = phase { return Self.format(seconds: Int(m.extraTimeHalfLength)) }
        if case .extraTimeSecond = phase { return Self.format(seconds: Int(m.extraTimeHalfLength)) }
        let per = m.duration / TimeInterval(max(1, m.numberOfPeriods))
        return Self.format(seconds: Int(per))
    }

    private func teamButton(_ side: TeamSide, name: String, score: Int) -> some View {
        Button {
            selected = side
        } label: {
            VStack(spacing: AppTheme.Spacing.s) {
                Text(name).font(AppTheme.Typography.header)
                Text("\(score)")
                    .font(AppTheme.Typography.scoreL)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Corners.m)
                    .fill((selected == side) ? Color.green.opacity(0.8) : Color(.secondarySystemBackground))
            )
            .foregroundStyle((selected == side) ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(side == .home ? "homeTeamButton" : "awayTeamButton")
        .accessibilityLabel(Text(String(format: NSLocalizedString("kickoff_select_team_accessibility", comment: ""), name)))
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
