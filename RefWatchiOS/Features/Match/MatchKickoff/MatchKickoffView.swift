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
        case secondHalf
        case extraTimeFirst
        case extraTimeSecond
    }

    let matchViewModel: MatchViewModel
    let phase: Phase
    let defaultSelected: TeamSide?
    @Environment(\.dismiss) private var dismiss
    @State private var selected: TeamSide?

    init(matchViewModel: MatchViewModel, phase: Phase, defaultSelected: TeamSide? = nil) {
        self.matchViewModel = matchViewModel
        self.phase = phase
        self.defaultSelected = defaultSelected
        _selected = State(initialValue: defaultSelected)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(headerTitle)
                        .font(.headline)
                    Text(durationLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
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
                    Label("Start", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected == nil && phase != .extraTimeSecond)
                .padding(.horizontal)
            }
            .navigationTitle("Kickoff")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Ensure defaults are set on appear (covers ET second half default override case)
            if selected == nil, let d = defaultSelected { selected = d }
        }
    }

    private var headerTitle: String {
        switch phase {
        case .secondHalf: return "Second Half"
        case .extraTimeFirst: return "Extra Time 1"
        case .extraTimeSecond: return "Extra Time 2"
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
            VStack(spacing: 8) {
                Text(name).font(.headline)
                Text("\(score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((selected == side) ? Color.green.opacity(0.8) : Color(.secondarySystemBackground))
            )
            .foregroundStyle((selected == side) ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(side == .home ? "homeTeamButton" : "awayTeamButton")
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

