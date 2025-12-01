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
    @State private var showEndHalfTimeConfirm = false
    @State private var errorAlert = ErrorAlertState()
    @State private var activeSheet: ActiveSheet? = nil
    @State private var kickoffDefaultSecond: TeamSide? = nil
    @State private var kickoffDefaultET2: TeamSide? = nil
    @State private var chainToPenaltyShootout = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

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
        VStack(spacing: theme.spacing.l) {
            // Header
            HStack {
                Text(periodLabel)
                    .font(theme.typography.heroSubtitle)
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
            VStack(spacing: theme.spacing.xs) {
                Text(matchViewModel.matchTime)
                    .font(theme.typography.timerPrimary)
                    .monospacedDigit()
                    .accessibilityIdentifier("timerArea")
                Text(matchViewModel.periodTimeRemaining)
                    .font(theme.typography.timerSecondary)
                    .foregroundStyle(theme.colors.textSecondary)
                    .monospacedDigit()
                if matchViewModel.isInStoppage {
                    Text("+\(matchViewModel.formattedStoppageTime)")
                        .font(theme.typography.timerTertiary)
                        .foregroundStyle(theme.colors.matchWarning)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.6) {
                if matchViewModel.isMatchInProgress || matchViewModel.isHalfTime {
                    activeSheet = .actions
                }
            }
            .onTapGesture(count: 2) {
                guard matchViewModel.isMatchInProgress else { return }
                if matchViewModel.isPaused {
                    matchViewModel.resumeMatch()
                } else {
                    matchViewModel.pauseMatch()
                }
            }

            // Controls / Half-time
            if matchViewModel.isHalfTime {
                halfTimeSection
            } else {
                controlButtons
            }

            pendingConfirmationBanner

            EventsLogView(matchViewModel: matchViewModel, theme: theme)
        }
        .navigationTitle("Match Timer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { activeSheet = .actions } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
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
                MatchActionsSheet(
                    matchViewModel: matchViewModel,
                    onRecordGoal: { activeSheet = .goal },
                    onRecordCard: { activeSheet = .card },
                    onRecordSubstitution: { activeSheet = .substitution },
                    onStartNextPeriod: { matchViewModel.startNextPeriod() },
                    onEndPeriod: { matchViewModel.endCurrentPeriod() },
                    onFinishMatch: { activeSheet = .fullTime }
                )
            case .goal:
                GoalEventFlowView(matchViewModel: matchViewModel, onSaved: { activeSheet = nil })
            case .card:
                CardEventFlowView(matchViewModel: matchViewModel, onSaved: { activeSheet = nil })
            case .substitution:
                SubstitutionEventFlowView(matchViewModel: matchViewModel, onSaved: { activeSheet = nil })
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

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: theme.spacing.m) {
            if !matchViewModel.isMatchInProgress {
                Button("Start") { matchViewModel.startMatch() }
            } else if matchViewModel.isPaused {
                Button("Resume") { matchViewModel.resumeMatch() }
            } else {
                Button("Pause") { matchViewModel.pauseMatch() }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.colors.accentSecondary)
        .padding(.horizontal)

        if matchViewModel.waitingForHalfTimeStart {
            Button("Start Half‑time") { matchViewModel.startHalfTimeManually() }
                .buttonStyle(.bordered)
                .tint(theme.colors.accentSecondary)
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
        case goal
        case card
        case substitution
        case fullTime
        case kickoffSecond(TeamSide?)
        case kickoffET1
        case kickoffET2(TeamSide?)
        case penFirst
        case penShootout

        var id: String {
            switch self {
            case .actions: return "actions"
            case .goal: return "goal"
            case .card: return "card"
            case .substitution: return "substitution"
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
    private var pendingConfirmationBanner: some View {
        if matchViewModel.pendingConfirmation != nil {
            HStack(spacing: theme.spacing.s) {
                Label("Event saved", systemImage: "checkmark.circle")
                    .font(.subheadline)
                Spacer()
                Button("Undo") {
                    _ = matchViewModel.undoLastUserEvent()
                    matchViewModel.clearPendingConfirmation()
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, theme.spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                    .fill(theme.colors.backgroundElevated)
            )
            .padding(.horizontal)
        }
    }
    @ViewBuilder
    var halfTimeSection: some View {
        VStack(spacing: theme.spacing.s) {
            Text(matchViewModel.halfTimeElapsed)
                .font(theme.typography.timerPrimary)
                .monospacedDigit()
            Button("End Half‑time") { showEndHalfTimeConfirm = true }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors.accentSecondary)
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

private struct EventsLogView: View {
    let matchViewModel: MatchViewModel
    let theme: Theme
    @State private var lastEventID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("Events")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
                .padding(.horizontal)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacing.s) {
                        if matchViewModel.matchEvents.isEmpty {
                            Text("No events yet. Use Actions to record goals, cards, or subs.")
                                .font(.footnote)
                                .foregroundStyle(theme.colors.textSecondary)
                                .padding(.horizontal)
                                .padding(.vertical, theme.spacing.s)
                        } else {
                            ForEach(matchViewModel.matchEvents) { event in
                                EventRow(event: event, theme: theme)
                                    .id(event.id)
                                Divider()
                                    .opacity(event.id == matchViewModel.matchEvents.last?.id ? 0 : 0.3)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear { scrollToLatest(proxy) }
                .onChange(of: matchViewModel.matchEvents.count) { _ in
                    scrollToLatest(proxy)
                }
            }
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastID = matchViewModel.matchEvents.last?.id else { return }
        if lastEventID == lastID { return }
        lastEventID = lastID
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

private struct EventRow: View {
    let event: MatchEventRecord
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            Image(systemName: icon(for: event))
                .foregroundStyle(color(for: event))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.matchTime)
                        .font(.caption)
                        .monospacedDigit()
                        .bold()
                    Spacer()
                    Text(event.periodDisplayName)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                if let team = event.teamDisplayName {
                    Text(team)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Text(event.displayDescription)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
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
        case .goal: return theme.colors.matchPositive
        case .card(let details):
            return details.cardType == .yellow ? theme.colors.matchNeutral : theme.colors.matchCritical
        case .substitution: return theme.colors.accentSecondary
        case .kickOff, .periodStart: return theme.colors.matchPositive
        case .halfTime: return theme.colors.matchWarning
        case .periodEnd, .matchEnd: return theme.colors.matchCritical
        case .penaltiesStart: return theme.colors.accentMuted
        case .penaltyAttempt(let details):
            return details.result == .scored ? theme.colors.matchPositive : theme.colors.matchCritical
        case .penaltiesEnd: return theme.colors.matchPositive
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
