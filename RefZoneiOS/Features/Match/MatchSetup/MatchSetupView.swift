//
//  MatchSetupView.swift
//  RefZoneiOS
//
//  iOS setup form for creating and starting a match using RefWatchCore.
//  Skeleton only — navigation is delegated via optional onStarted closure.
//

import SwiftUI
import RefWatchCore

struct MatchSetupView: View {
    let matchViewModel: MatchViewModel
    var onStarted: ((MatchViewModel) -> Void)? = nil

    // Basic inputs (sensible defaults)
    @State private var homeTeam: String = "Home"
    @State private var awayTeam: String = "Away"
    @State private var durationMinutes: Int = 90
    @State private var halfTimeMinutes: Int = 15
    @State private var hasExtraTime: Bool = false
    @State private var etHalfMinutes: Int = 15
    @State private var hasPenalties: Bool = false
    @State private var penaltyRounds: Int = 5

    @State private var validationMessage: String?
    @State private var showKickoffFirstHalf: Bool = false

    init(matchViewModel: MatchViewModel, onStarted: ((MatchViewModel) -> Void)? = nil, prefillTeams: (String, String)? = nil) {
        self.matchViewModel = matchViewModel
        self.onStarted = onStarted
        if let teams = prefillTeams {
            _homeTeam = State(initialValue: teams.0)
            _awayTeam = State(initialValue: teams.1)
        }
    }

    var body: some View {
        Form {
            Section("Teams") {
                TextField("Home Team", text: $homeTeam)
                    .textInputAutocapitalization(.words)
                    .onChange(of: homeTeam) { _ in validate() }
                TextField("Away Team", text: $awayTeam)
                    .textInputAutocapitalization(.words)
                    .onChange(of: awayTeam) { _ in validate() }
                if let msg = validationMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Validation error: \(msg)")
                }
            }

            Section("Configuration") {
                Stepper(value: $durationMinutes, in: 30...150, step: 5) {
                    LabeledContent("Duration", value: "\(durationMinutes) min")
                }
                Stepper(value: $halfTimeMinutes, in: 5...30, step: 5) {
                    LabeledContent("Half‑time", value: "\(halfTimeMinutes) min")
                }
                Toggle("Extra Time", isOn: $hasExtraTime)
                if hasExtraTime {
                    Stepper(value: $etHalfMinutes, in: 5...30, step: 5) {
                        LabeledContent("ET half length", value: "\(etHalfMinutes) min")
                    }
                }
                Toggle("Penalties", isOn: $hasPenalties)
                if hasPenalties {
                    Stepper(value: $penaltyRounds, in: 1...10) {
                        LabeledContent("Initial rounds", value: "\(penaltyRounds)")
                    }
                }
            }

            Section {
                Button {
                    startMatch()
                } label: {
                    Label("Start Match", systemImage: "play.circle.fill")
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle("Match Setup")
        .sheet(isPresented: $showKickoffFirstHalf) {
            MatchKickoffView(
                matchViewModel: matchViewModel,
                phase: .firstHalf,
                onConfirmStart: { onStarted?(matchViewModel) }
            )
        }
    }

    private var isValid: Bool { validate() }

    @discardableResult
    private func validate() -> Bool {
        func validTeam(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
            return CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(CharacterSet(charactersIn: "-&'."))
                .isSuperset(of: CharacterSet(charactersIn: trimmed))
        }

        if !validTeam(homeTeam) { validationMessage = "Enter a valid Home team (max 40)."; return false }
        if !validTeam(awayTeam) { validationMessage = "Enter a valid Away team (max 40)."; return false }
        validationMessage = nil
        return true
    }

    private func startMatch() {
        let m = Match(
            homeTeam: homeTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            awayTeam: awayTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: TimeInterval(durationMinutes * 60),
            numberOfPeriods: 2,
            halfTimeLength: TimeInterval(halfTimeMinutes * 60),
            extraTimeHalfLength: TimeInterval(etHalfMinutes * 60),
            hasExtraTime: hasExtraTime,
            hasPenalties: hasPenalties,
            penaltyInitialRounds: penaltyRounds
        )

        matchViewModel.newMatch = m
        matchViewModel.createMatch()
        // Defer kickoff + start to first-half kickoff sheet
        showKickoffFirstHalf = true
    }
}

#Preview {
    let vm = MatchViewModel(haptics: NoopHaptics())
    return NavigationStack { MatchSetupView(matchViewModel: vm) }
}
