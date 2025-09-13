//
//  MatchTimerView.swift
//  RefZoneiOS
//
//  iOS live timer skeleton for an in-progress match.
//  Shows period label, timers, a simple score strip and core controls.
//

import SwiftUI
import RefWatchCore

struct MatchTimerView: View {
    let matchViewModel: MatchViewModel
    @State private var showingFinishAlert = false
    @State private var showEndHalfTimeConfirm = false
    @State private var errorAlert = ErrorAlertState()
    @State private var activeSheet: ActiveSheet? = nil
    @State private var kickoffDefaultSecond: TeamSide? = nil
    @State private var kickoffDefaultET2: TeamSide? = nil
    @State private var chainToPenaltyShootout = false
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
                    .font(AppTheme.Typography.timerXL)
                    .monospacedDigit()
                    .accessibilityIdentifier("timerArea")
                Text(matchViewModel.periodTimeRemaining)
                    .font(AppTheme.Typography.timerSub)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if matchViewModel.isInStoppage {
                    Text("+\(matchViewModel.formattedStoppageTime)")
                        .font(AppTheme.Typography.timerStoppage)
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.6) {
                if matchViewModel.isMatchInProgress || matchViewModel.isHalfTime {
                    activeSheet = .actions
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
                Button { activeSheet = .actions } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Finish Match?", isPresented: $showingFinishAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Finish", role: .destructive) {
                matchViewModel.finalizeMatch()
                if let err = matchViewModel.lastPersistenceError, !err.isEmpty { errorAlert.present(err) }
            }
        } message: {
            Text("This will finalize and save the match.")
        }
        .onChange(of: matchViewModel.isFullTime) { isFT in
            if isFT { activeSheet = .fullTime }
        }
        .onChange(of: matchViewModel.matchCompleted) { completed in
            // After finalize, pop back to Matches hub (if we are still on timer)
            if completed { dismiss() }
        }
        .onChange(of: matchViewModel.waitingForSecondHalfStart) { waiting in
            if waiting {
                kickoffDefaultSecond = matchViewModel.getSecondHalfKickingTeam()
                activeSheet = .kickoffSecond(kickoffDefaultSecond)
            }
        }
        .onChange(of: matchViewModel.waitingForET1Start) { waiting in
            if waiting { activeSheet = .kickoffET1 }
        }
        .onChange(of: matchViewModel.waitingForET2Start) { waiting in
            if waiting {
                kickoffDefaultET2 = matchViewModel.getETSecondHalfKickingTeam()
                activeSheet = .kickoffET2(kickoffDefaultET2)
            }
        }
        .onChange(of: matchViewModel.waitingForPenaltiesStart) { waiting in
            if waiting { chainToPenaltyShootout = true; activeSheet = .penFirst }
        }
        .alert("Save Failed", isPresented: $errorAlert.isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlert.message)
        }
        .sheet(item: $activeSheet, onDismiss: {
            if chainToPenaltyShootout {
                chainToPenaltyShootout = false
                if matchViewModel.penaltyShootoutActive { activeSheet = .penShootout }
            }
        }) { sheet in
            switch sheet {
            case .actions:
                MatchActionsSheet(matchViewModel: matchViewModel)
            case .fullTime:
                FullTimeView_iOS(matchViewModel: matchViewModel)
            case .kickoffSecond(let def):
                MatchKickoffView(matchViewModel: matchViewModel, phase: .secondHalf, defaultSelected: def)
            case .kickoffET1:
                MatchKickoffView(matchViewModel: matchViewModel, phase: .extraTimeFirst)
            case .kickoffET2(let def):
                MatchKickoffView(matchViewModel: matchViewModel, phase: .extraTimeSecond, defaultSelected: def)
            case .penFirst:
                PenaltyFirstKickerView(matchViewModel: matchViewModel)
            case .penShootout:
                PenaltyShootoutView(matchViewModel: matchViewModel)
            }
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
    }

    // Team column helper removed; using ScoreStripView instead.
}

private extension MatchTimerView {
    struct ErrorAlertState {
        var isPresented: Bool = false
        var message: String = ""
        mutating func present(_ msg: String) { message = msg; isPresented = true }
    }

    enum ActiveSheet: Identifiable {
        case actions
        case fullTime
        case kickoffSecond(TeamSide?)
        case kickoffET1
        case kickoffET2(TeamSide?)
        case penFirst
        case penShootout

        var id: String {
            switch self {
            case .actions: return "actions"
            case .fullTime: return "fullTime"
            case .kickoffSecond: return "kickoffSecond"
            case .kickoffET1: return "kickoffET1"
            case .kickoffET2: return "kickoffET2"
            case .penFirst: return "penFirst"
            case .penShootout: return "penShootout"
            }
        }
    }
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
