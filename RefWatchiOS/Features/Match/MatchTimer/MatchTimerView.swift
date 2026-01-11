//
//  MatchTimerView.swift
//  RefWatchiOS
//
//  iOS live timer skeleton for an in-progress match.
//  Shows period label, timers, a simple score strip and core controls.
//

import RefWatchCore
import SwiftUI

struct MatchTimerView: View {
  let matchViewModel: MatchViewModel
  @State private var showEndHalfTimeConfirm = false
  @State private var errorAlert = ErrorAlertState()
  @State private var activeSheet: ActiveSheet?
  @State private var kickoffDefaultSecond: TeamSide?
  @State private var kickoffDefaultET2: TeamSide?
  @State private var chainToPenaltyShootout = false
  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme

  private var periodLabel: String {
    if self.matchViewModel.isHalfTime, !self.matchViewModel.waitingForHalfTimeStart {
      "Half Time"
    } else if self.matchViewModel.waitingForHalfTimeStart {
      "Half Time"
    } else if self.matchViewModel.waitingForSecondHalfStart {
      "Second Half"
    } else {
      switch self.matchViewModel.currentPeriod {
      case 1: "First Half"
      case 2: "Second Half"
      case 3: "Extra Time 1"
      case 4: "Extra Time 2"
      default: "Penalties"
      }
    }
  }

  var body: some View {
    VStack(spacing: self.theme.spacing.l) {
      // Header
      HStack {
        Text(self.periodLabel)
          .font(self.theme.typography.heroSubtitle)
        Spacer()
      }
      .padding(.horizontal)

      // Score strip
      ScoreStripView(
        homeTeam: self.matchViewModel.currentMatch?.homeTeam ?? self.matchViewModel.homeTeam,
        awayTeam: self.matchViewModel.currentMatch?.awayTeam ?? self.matchViewModel.awayTeam,
        homeScore: self.matchViewModel.currentMatch?.homeScore ?? 0,
        awayScore: self.matchViewModel.currentMatch?.awayScore ?? 0)

      // Timers
      VStack(spacing: self.theme.spacing.xs) {
        Text(self.matchViewModel.matchTime)
          .font(self.theme.typography.timerPrimary)
          .monospacedDigit()
          .accessibilityIdentifier("timerArea")
        Text(self.matchViewModel.periodTimeRemaining)
          .font(self.theme.typography.timerSecondary)
          .foregroundStyle(self.theme.colors.textSecondary)
          .monospacedDigit()
        if self.matchViewModel.isInStoppage {
          Text("+\(self.matchViewModel.formattedStoppageTime)")
            .font(self.theme.typography.timerTertiary)
            .foregroundStyle(self.theme.colors.matchWarning)
            .monospacedDigit()
        }
      }
      .contentShape(Rectangle())
      .onLongPressGesture(minimumDuration: 0.6) {
        if self.matchViewModel.isMatchInProgress || self.matchViewModel.isHalfTime {
          self.activeSheet = .actions
        }
      }
      .onTapGesture(count: 2) {
        guard self.matchViewModel.isMatchInProgress else { return }
        if self.matchViewModel.isPaused {
          self.matchViewModel.resumeMatch()
        } else {
          self.matchViewModel.pauseMatch()
        }
      }

      // Controls / Half-time
      if self.matchViewModel.isHalfTime {
        halfTimeSection
      } else {
        self.controlButtons
      }

      pendingConfirmationBanner

      EventsLogView(matchViewModel: self.matchViewModel, theme: self.theme)
    }
    .navigationTitle("Match Timer")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { self.activeSheet = .actions } label: {
          Label("Actions", systemImage: "ellipsis.circle")
        }
      }
    }
    .onChange(of: self.matchViewModel.isFullTime) { _, isFT in
      if isFT { self.activeSheet = .fullTime }
    }
    .onChange(of: self.matchViewModel.matchCompleted) { _, completed in
      // After finalize, pop back to Matches hub (if we are still on timer)
      if completed { self.dismiss() }
    }
    .onChange(of: self.matchViewModel.waitingForSecondHalfStart) { _, waiting in
      if waiting {
        self.kickoffDefaultSecond = self.matchViewModel.getSecondHalfKickingTeam()
        self.activeSheet = .kickoffSecond(self.kickoffDefaultSecond)
      }
    }
    .onChange(of: self.matchViewModel.waitingForET1Start) { _, waiting in
      if waiting { self.activeSheet = .kickoffET1 }
    }
    .onChange(of: self.matchViewModel.waitingForET2Start) { _, waiting in
      if waiting {
        self.kickoffDefaultET2 = self.matchViewModel.getETSecondHalfKickingTeam()
        self.activeSheet = .kickoffET2(self.kickoffDefaultET2)
      }
    }
    .onChange(of: self.matchViewModel.waitingForPenaltiesStart) { _, waiting in
      if waiting { self.chainToPenaltyShootout = true; self.activeSheet = .penFirst }
    }
    .alert("Save Failed", isPresented: self.$errorAlert.isPresented) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(self.errorAlert.message)
    }
    .sheet(
      item: self.$activeSheet,
      onDismiss: {
        if self.chainToPenaltyShootout {
          self.chainToPenaltyShootout = false
          if self.matchViewModel.penaltyShootoutActive { self.activeSheet = .penShootout }
        }
      },
      content: { sheet in
        switch sheet {
        case .actions:
          MatchActionsSheet(
            matchViewModel: self.matchViewModel,
            onRecordGoal: { self.activeSheet = .goal },
            onRecordCard: { self.activeSheet = .card },
            onRecordSubstitution: { self.activeSheet = .substitution },
            onStartNextPeriod: { self.matchViewModel.startNextPeriod() },
            onEndPeriod: { self.matchViewModel.endCurrentPeriod() },
            onFinishMatch: { self.activeSheet = .fullTime })
        case .goal:
          GoalEventFlowView(matchViewModel: self.matchViewModel, onSaved: { self.activeSheet = nil })
        case .card:
          CardEventFlowView(matchViewModel: self.matchViewModel, onSaved: { self.activeSheet = nil })
        case .substitution:
          SubstitutionEventFlowView(matchViewModel: self.matchViewModel, onSaved: { self.activeSheet = nil })
        case .fullTime:
          FullTimeView_iOS(matchViewModel: self.matchViewModel)
        case let .kickoffSecond(def):
          MatchKickoffView(matchViewModel: self.matchViewModel, phase: .secondHalf, defaultSelected: def)
        case .kickoffET1:
          MatchKickoffView(matchViewModel: self.matchViewModel, phase: .extraTimeFirst)
        case let .kickoffET2(def):
          MatchKickoffView(matchViewModel: self.matchViewModel, phase: .extraTimeSecond, defaultSelected: def)
        case .penFirst:
          PenaltyFirstKickerView(matchViewModel: self.matchViewModel)
        case .penShootout:
          PenaltyShootoutView(matchViewModel: self.matchViewModel)
        }
      })
  }

  @ViewBuilder
  private var controlButtons: some View {
    HStack(spacing: self.theme.spacing.m) {
      if !self.matchViewModel.isMatchInProgress {
        Button("Start") { self.matchViewModel.startMatch() }
      } else if self.matchViewModel.isPaused {
        Button("Resume") { self.matchViewModel.resumeMatch() }
      } else {
        Button("Pause") { self.matchViewModel.pauseMatch() }
      }
    }
    .buttonStyle(.borderedProminent)
    .tint(self.theme.colors.accentSecondary)
    .padding(.horizontal)

    if self.matchViewModel.waitingForHalfTimeStart {
      Button("Start Half‑time") { self.matchViewModel.startHalfTimeManually() }
        .buttonStyle(.bordered)
        .tint(self.theme.colors.accentSecondary)
        .padding(.horizontal)
    }
  }

  // Team column helper removed; using ScoreStripView instead.
}

extension MatchTimerView {
  fileprivate struct ErrorAlertState {
    var isPresented: Bool = false
    var message: String = ""
    mutating func present(_ msg: String) { self.message = msg; self.isPresented = true }
  }

  fileprivate enum ActiveSheet: Identifiable {
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
      case .actions: "actions"
      case .goal: "goal"
      case .card: "card"
      case .substitution: "substitution"
      case .fullTime: "fullTime"
      case .kickoffSecond: "kickoffSecond"
      case .kickoffET1: "kickoffET1"
      case .kickoffET2: "kickoffET2"
      case .penFirst: "penFirst"
      case .penShootout: "penShootout"
      }
    }
  }

  @ViewBuilder
  private var pendingConfirmationBanner: some View {
    if self.matchViewModel.pendingConfirmation != nil {
      HStack(spacing: self.theme.spacing.s) {
        Label("Event saved", systemImage: "checkmark.circle")
          .font(.subheadline)
        Spacer()
        Button("Undo") {
          _ = self.matchViewModel.undoLastUserEvent()
          self.matchViewModel.clearPendingConfirmation()
        }
        .buttonStyle(.borderless)
      }
      .padding(.horizontal)
      .padding(.vertical, self.theme.spacing.xs)
      .background(
        RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius)
          .fill(self.theme.colors.backgroundElevated))
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private var halfTimeSection: some View {
    VStack(spacing: self.theme.spacing.s) {
      Text(self.matchViewModel.halfTimeElapsed)
        .font(self.theme.typography.timerPrimary)
        .monospacedDigit()
      Button("End Half‑time") { self.showEndHalfTimeConfirm = true }
        .buttonStyle(.borderedProminent)
        .tint(self.theme.colors.accentSecondary)
    }
    .padding(.horizontal)
    .confirmationDialog("", isPresented: self.$showEndHalfTimeConfirm, titleVisibility: .hidden) {
      Button("Yes") { self.matchViewModel.endHalfTimeManually() }
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
    VStack(alignment: .leading, spacing: self.theme.spacing.s) {
      Text("Events")
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)
        .padding(.horizontal)

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: self.theme.spacing.s) {
            if self.matchViewModel.matchEvents.isEmpty {
              Text("No events yet. Use Actions to record goals, cards, or subs.")
                .font(.footnote)
                .foregroundStyle(self.theme.colors.textSecondary)
                .padding(.horizontal)
                .padding(.vertical, self.theme.spacing.s)
            } else {
              ForEach(self.matchViewModel.matchEvents) { event in
                EventRow(event: event, theme: self.theme)
                  .id(event.id)
                Divider()
                  .opacity(event.id == self.matchViewModel.matchEvents.last?.id ? 0 : 0.3)
              }
            }
          }
          .padding(.horizontal)
        }
        .onAppear { self.scrollToLatest(proxy) }
        .onChange(of: self.matchViewModel.matchEvents.count) { _, _ in
          self.scrollToLatest(proxy)
        }
      }
    }
  }

  private func scrollToLatest(_ proxy: ScrollViewProxy) {
    guard let lastID = matchViewModel.matchEvents.last?.id else { return }
    if self.lastEventID == lastID { return }
    self.lastEventID = lastID
    withAnimation(.easeInOut(duration: 0.25)) {
      proxy.scrollTo(lastID, anchor: .bottom)
    }
  }
}

private struct EventRow: View {
  let event: MatchEventRecord
  let theme: Theme

  var body: some View {
    HStack(spacing: self.theme.spacing.m) {
      Image(systemName: self.icon(for: self.event))
        .foregroundStyle(self.color(for: self.event))
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(self.event.matchTime)
            .font(.caption)
            .monospacedDigit()
            .bold()
          Spacer()
          Text(self.event.periodDisplayName)
            .font(.caption2)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
        if let team = event.teamDisplayName {
          Text(team)
            .font(.caption2)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
        Text(self.event.displayDescription)
          .font(.caption)
      }
    }
    .padding(.vertical, 2)
  }

  private func icon(for event: MatchEventRecord) -> String {
    switch event.eventType {
    case .goal: "soccerball"
    case let .card(details): details.cardType == .yellow ? "square.fill" : "square.fill"
    case .substitution: "arrow.up.arrow.down"
    case .kickOff: "play.circle"
    case .periodStart: "play.circle.fill"
    case .halfTime: "pause.circle"
    case .periodEnd: "stop.circle"
    case .matchEnd: "stop.circle.fill"
    case .penaltiesStart: "flag"
    case let .penaltyAttempt(details): details.result == .scored ? "checkmark.circle" : "xmark.circle"
    case .penaltiesEnd: "flag.checkered"
    }
  }

  private func color(for event: MatchEventRecord) -> Color {
    switch event.eventType {
    case .goal: self.theme.colors.matchPositive
    case let .card(details):
      details.cardType == .yellow ? self.theme.colors.matchNeutral : self.theme.colors.matchCritical
    case .substitution: self.theme.colors.accentSecondary
    case .kickOff, .periodStart: self.theme.colors.matchPositive
    case .halfTime: self.theme.colors.matchWarning
    case .periodEnd, .matchEnd: self.theme.colors.matchCritical
    case .penaltiesStart: self.theme.colors.accentMuted
    case let .penaltyAttempt(details):
      details.result == .scored ? self.theme.colors.matchPositive : self.theme.colors.matchCritical
    case .penaltiesEnd: self.theme.colors.matchPositive
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
