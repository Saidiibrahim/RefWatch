//
//  MatchTimerView.swift
//  RefWatchiOS
//
//  iOS live timer skeleton for an in-progress match.
//  Shows period label, timers, a simple score strip and core controls.
//

import SwiftUI
import RefWatchCore

struct MatchTimerView: View {
    let matchViewModel: MatchViewModel
    @State private var showingFinishAlert = false
    @State private var showingSaveErrorAlert = false
    @State private var saveErrorMessage: String = ""
    @State private var showingActions = false
    @State private var showingFullTime = false
    @State private var showKickoffSecond = false
    @State private var showKickoffET1 = false
    @State private var showKickoffET2 = false
    @State private var kickoffDefaultSecond: TeamSide? = nil
    @State private var kickoffDefaultET2: TeamSide? = nil
    @State private var showPenFirst = false
    @State private var showPenShootout = false
    @State private var showEndHalfTimeConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var periodLabel: String {
        if matchViewModel.isHalfTime && !matchViewModel.waitingForHalfTimeStart {
            return "Half Time"
        } else if matchViewModel.waitingForHalfTimeStart {
            return "Half Time"
        } else if matchViewModel.waitingForSecondHalfStart {
            return "Second Half"
        } else {
            switch matchViewModel.currentPeriod {
            case 1: return "First Half"
            case 2: return "Second Half"
            case 3: return "Extra Time 1"
            case 4: return "Extra Time 2"
            default: return "Penalties"
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(periodLabel)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            // Score strip
            ScoreStripView(
                homeTeam: matchViewModel.currentMatch?.homeTeam ?? matchViewModel.homeTeam,
                awayTeam: matchViewModel.currentMatch?.awayTeam ?? matchViewModel.awayTeam,
                homeScore: matchViewModel.currentMatch?.homeScore ?? 0,
                awayScore: matchViewModel.currentMatch?.awayScore ?? 0
            )

            // Timers
            VStack(spacing: 4) {
                Text(matchViewModel.matchTime)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityIdentifier("timerArea")
                Text(matchViewModel.periodTimeRemaining)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if matchViewModel.isInStoppage {
                    Text("+\(matchViewModel.formattedStoppageTime)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
            }

            // Controls / Half-time
            if matchViewModel.isHalfTime {
                halfTimeSection
            } else {
                controlButtons
            }

            // Recent events
            List {
                let items = Array(matchViewModel.matchEvents.suffix(25).reversed())
                ForEach(items) { event in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: event))
                            .foregroundStyle(color(for: event))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(event.matchTime)
                                    .font(.caption).monospacedDigit().bold()
                                Spacer()
                                Text(event.periodDisplayName)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            if let team = event.teamDisplayName {
                                Text(team).font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(event.displayDescription).font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxHeight: 220)
        }
        .navigationTitle("Match Timer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showingFinishAlert = true } label: {
                    Text("Finish")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingActions = true } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Finish Match?", isPresented: $showingFinishAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Finish", role: .destructive) {
                matchViewModel.finalizeMatch()
                if let err = matchViewModel.lastPersistenceError, !err.isEmpty {
                    saveErrorMessage = err
                    showingSaveErrorAlert = true
                }
            }
        } message: {
            Text("This will finalize and save the match.")
        }
        .onChange(of: matchViewModel.isFullTime) { isFT in
            if isFT { showingFullTime = true }
        }
        .onChange(of: matchViewModel.matchCompleted) { completed in
            // After finalize, pop back to Matches hub (if we are still on timer)
            if completed { dismiss() }
        }
        .onChange(of: matchViewModel.waitingForSecondHalfStart) { waiting in
            if waiting {
                kickoffDefaultSecond = matchViewModel.getSecondHalfKickingTeam()
                showKickoffSecond = true
            }
        }
        .onChange(of: matchViewModel.waitingForET1Start) { waiting in
            if waiting { showKickoffET1 = true }
        }
        .onChange(of: matchViewModel.waitingForET2Start) { waiting in
            if waiting {
                kickoffDefaultET2 = matchViewModel.getETSecondHalfKickingTeam()
                showKickoffET2 = true
            }
        }
        .onChange(of: matchViewModel.waitingForPenaltiesStart) { waiting in
            if waiting { showPenFirst = true }
        }
        .alert("Save Failed", isPresented: $showingSaveErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage.isEmpty ? "An unknown error occurred while saving." : saveErrorMessage)
        }
        .sheet(isPresented: $showingActions) {
            MatchActionsSheet(matchViewModel: matchViewModel)
        }
        .sheet(isPresented: $showingFullTime) {
            FullTimeView_iOS(matchViewModel: matchViewModel)
        }
        .sheet(isPresented: $showKickoffSecond) {
            MatchKickoffView(
                matchViewModel: matchViewModel,
                phase: .secondHalf,
                defaultSelected: kickoffDefaultSecond
            )
        }
        .sheet(isPresented: $showKickoffET1) {
            MatchKickoffView(
                matchViewModel: matchViewModel,
                phase: .extraTimeFirst
            )
        }
        .sheet(isPresented: $showKickoffET2) {
            MatchKickoffView(
                matchViewModel: matchViewModel,
                phase: .extraTimeSecond,
                defaultSelected: kickoffDefaultET2
            )
        }
        .sheet(isPresented: $showPenFirst, onDismiss: {
            if matchViewModel.penaltyShootoutActive { showPenShootout = true }
        }) {
            PenaltyFirstKickerView(matchViewModel: matchViewModel)
        }
        .sheet(isPresented: $showPenShootout) {
            PenaltyShootoutView(matchViewModel: matchViewModel)
        }
    }

    private func icon(for event: MatchEventRecord) -> String {
        switch event.eventType {
        case .goal: return "soccerball"
        case .card(let details): return details.cardType == .yellow ? "square.fill" : "square.fill"
        case .substitution: return "arrow.up.arrow.down"
        case .kickOff: return "play.circle"
        case .periodStart: return "play.circle.fill"
        case .halfTime: return "pause.circle"
        case .periodEnd: return "stop.circle"
        case .matchEnd: return "stop.circle.fill"
        case .penaltiesStart: return "flag"
        case .penaltyAttempt(let details): return details.result == .scored ? "checkmark.circle" : "xmark.circle"
        case .penaltiesEnd: return "flag.checkered"
        }
    }

    private func color(for event: MatchEventRecord) -> Color {
        switch event.eventType {
        case .goal: return .green
        case .card(let details): return details.cardType == .yellow ? .yellow : .red
        case .substitution: return .blue
        case .kickOff, .periodStart: return .green
        case .halfTime: return .orange
        case .periodEnd, .matchEnd: return .red
        case .penaltiesStart: return .orange
        case .penaltyAttempt(let details): return details.result == .scored ? .green : .red
        case .penaltiesEnd: return .green
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 12) {
            if !matchViewModel.isMatchInProgress {
                Button("Start") { matchViewModel.startMatch() }
            } else if matchViewModel.isPaused {
                Button("Resume") { matchViewModel.resumeMatch() }
                Button("Next Period") { matchViewModel.startNextPeriod() }
            } else {
                Button("Pause") { matchViewModel.pauseMatch() }
            }
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)

        if matchViewModel.waitingForHalfTimeStart {
            Button("Start Half‑time") { matchViewModel.startHalfTimeManually() }
                .buttonStyle(.bordered)
                .padding(.horizontal)
        }
        if matchViewModel.waitingForSecondHalfStart {
            Button("Start Second Half") { matchViewModel.startSecondHalfManually() }
                .buttonStyle(.bordered)
                .padding(.horizontal)
        }
        if matchViewModel.waitingForET1Start {
            Button("Start ET First Half") { matchViewModel.startExtraTimeFirstHalfManually() }
                .buttonStyle(.bordered)
                .padding(.horizontal)
        }
        if matchViewModel.waitingForET2Start {
            Button("Start ET Second Half") { matchViewModel.startExtraTimeSecondHalfManually() }
                .buttonStyle(.bordered)
                .padding(.horizontal)
        }
    }

    // Team column helper removed; using ScoreStripView instead.
}

private extension MatchTimerView {
    @ViewBuilder
    var halfTimeSection: some View {
        VStack(spacing: 8) {
            Text(matchViewModel.halfTimeElapsed)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Button("End Half‑time") { showEndHalfTimeConfirm = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .confirmationDialog("", isPresented: $showEndHalfTimeConfirm, titleVisibility: .hidden) {
            Button("Yes") { matchViewModel.endHalfTimeManually() }
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to 'End Half'?")
        }
    }
}

#Preview {
    let vm = MatchViewModel(haptics: NoopHaptics())
    vm.newMatch = Match(homeTeam: "Leeds", awayTeam: "Newcastle")
    vm.createMatch()
    vm.startMatch()
    return NavigationStack { MatchTimerView(matchViewModel: vm) }
}
