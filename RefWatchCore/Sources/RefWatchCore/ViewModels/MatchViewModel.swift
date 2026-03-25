//
//  MatchViewModel.swift
//  RefWatchCore
//
//  Description: Shared match lifecycle view model covering timer state,
//  runtime-protection gating, and unfinished-match snapshot restore.
//

import Foundation
import Observation

// MARK: - TimerManager Integration

/// Shared source of truth for live match state across watchOS and iOS.
///
/// For Match Mode continuity on watchOS, the view model is also responsible for
/// deciding when workout-backed runtime protection should stay active and for
/// restoring unfinished-match snapshots after relaunch.
@Observable
@MainActor
public final class MatchViewModel {
  public struct EventSnapshot: Equatable {
    let timestamp: Date
    public let matchTime: String
    public let period: Int

    public init(timestamp: Date, matchTime: String, period: Int) {
      self.timestamp = timestamp
      self.matchTime = matchTime
      self.period = period
    }
  }

  // MARK: - Properties

  public internal(set) var currentMatch: Match?
  public private(set) var savedMatches: [Match]
  public private(set) var libraryTeams: [MatchLibraryTeam]
  public private(set) var libraryCompetitions: [MatchLibraryCompetition]
  public private(set) var libraryVenues: [MatchLibraryVenue]
  public private(set) var librarySchedules: [MatchLibrarySchedule]
  private let history: MatchHistoryStoring
  private let backgroundRuntimeManager: BackgroundRuntimeManaging?
  private let activeMatchSessionStore: ActiveMatchSessionStoring?
  private var librarySavedMatches: [Match]
  private var localSavedMatches: [Match]
  private enum LibraryScheduleStatus {
    case scheduled
    case inProgress
    case completed
    case canceled
  }

  public var newMatch: Match
  public var isMatchInProgress: Bool = false
  public var currentPeriod: Int = 1
  public var isHalfTime: Bool = false
  public var isPaused: Bool = false

  // Period transition states
  public var waitingForMatchStart: Bool = true
  public var waitingForHalfTimeStart: Bool = false
  public var waitingForSecondHalfStart: Bool = false
  public var waitingForET1Start: Bool = false
  public var waitingForET2Start: Bool = false
  public var waitingForPenaltiesStart: Bool = false
  public var pendingPeriodBoundaryDecision: PendingPeriodBoundaryDecision? = nil
  public var isFullTime: Bool = false
  public var matchCompleted: Bool = false

  // Timer properties (delegated)
  private let timerManager: TimerManager
  private var timer: Timer? // legacy retained for compatibility
  private var stoppageTimer: Timer? // legacy retained for compatibility
  private var elapsedTime: TimeInterval = 0 // maintained for formattedElapsedTime

  // Formatted time strings
  public var matchTime: String = "00:00"
  public var periodTime: String = "00:00"
  public var periodTimeRemaining: String = "00:00"
  public var halfTimeRemaining: String = "00:00"
  public var halfTimeElapsed: String = "00:00"

  // Stoppage time tracking
  private var stoppageTime: TimeInterval = 0
  private var stoppageStartTime: Date?
  public var isInStoppage: Bool = false
  public var formattedStoppageTime: String = "00:00"

  public var formattedElapsedTime: String {
    if self.isMatchInProgress {
      let minutes = Int(elapsedTime) / 60
      let seconds = Int(elapsedTime) % 60
      return String(format: "%02d:%02d", minutes, seconds)
    }
    return "00:00"
  }

  public var homeTeam: String = "HOM"
  public var awayTeam: String = "AWA"

  // Comprehensive match event tracking
  public private(set) var matchEvents: [MatchEventRecord] = []
  public private(set) var pendingConfirmation: MatchEventConfirmation?

  // Configuration mirrors
  public var matchDuration: Int = 90
  public var numberOfPeriods: Int = 2
  public var halfTimeLength: Int = 15
  public var hasExtraTime: Bool = false
  public var hasPenalties: Bool = false
  // Configurable extras
  public var extraTimeHalfLengthMinutes: Int = 15
  public var penaltyInitialRounds: Int = 5

  private(set) var homeTeamKickingOff: Bool = false
  private(set) var homeTeamKickingOffET1: Bool?

  // Penalties managed by PenaltyManager (SRP); injected for testing
  private let penaltyManager: PenaltyManaging
  private let haptics: HapticsProviding
  private let lifecycleHaptics: MatchLifecycleHapticsProviding
  private let connectivity: ConnectivitySyncProviding?
  private let scheduleStatusUpdater: MatchScheduleStatusUpdating?
  private var penaltyStartEventLogged = false

  // Persistence error feedback surfaced to UI (optional alert)
  public var lastPersistenceError: String?

  // Computed bridges to maintain current UI/View API
  public var penaltyShootoutActive: Bool { self.penaltyManager.isActive }
  public var homePenaltiesScored: Int { self.penaltyManager.homeScored }
  public var homePenaltiesTaken: Int { self.penaltyManager.homeTaken }
  public var awayPenaltiesScored: Int { self.penaltyManager.awayScored }
  public var awayPenaltiesTaken: Int { self.penaltyManager.awayTaken }
  public var homePenaltyResults: [PenaltyAttemptDetails.Result] { self.penaltyManager.homeResults }
  public var awayPenaltyResults: [PenaltyAttemptDetails.Result] { self.penaltyManager.awayResults }
  public var penaltyRoundsVisible: Int { self.penaltyManager.roundsVisible }
  public var nextPenaltyTeam: TeamSide { self.penaltyManager.nextTeam }
  public var penaltyFirstKicker: TeamSide { self.penaltyManager.firstKicker }
  public var isPenaltyShootoutDecided: Bool { self.penaltyManager.isDecided }
  public var penaltyWinner: TeamSide? { self.penaltyManager.winner }
  public var hasChosenPenaltyFirstKicker: Bool {
    get { self.penaltyManager.hasChosenFirstKicker }
    set { self.penaltyManager.markHasChosenFirstKicker(newValue) }
  }

  public var isSuddenDeathActive: Bool { self.penaltyManager.isSuddenDeathActive }

  public var homeTeamDisplayName: String { self.currentMatch?.homeTeam ?? self.homeTeam }
  public var awayTeamDisplayName: String { self.currentMatch?.awayTeam ?? self.awayTeam }

  // MARK: - Initialization

  @MainActor
  public init(
    history: MatchHistoryStoring,
    penaltyManager: PenaltyManaging = PenaltyManager(),
    haptics: HapticsProviding = NoopHaptics(),
    lifecycleHaptics: MatchLifecycleHapticsProviding = NoopMatchLifecycleHaptics(),
    connectivity: ConnectivitySyncProviding? = nil,
    backgroundRuntimeManager: BackgroundRuntimeManaging? = nil,
    activeMatchSessionStore: ActiveMatchSessionStoring? = nil,
    scheduleStatusUpdater: MatchScheduleStatusUpdating? = nil)
  {
    self.history = history
    self.penaltyManager = penaltyManager
    self.haptics = haptics
    self.lifecycleHaptics = lifecycleHaptics
    self.timerManager = TimerManager(lifecycleHaptics: lifecycleHaptics)
    self.connectivity = connectivity
    self.backgroundRuntimeManager = backgroundRuntimeManager
    self.activeMatchSessionStore = activeMatchSessionStore
    self.scheduleStatusUpdater = scheduleStatusUpdater
    self.savedMatches = []
    self.libraryTeams = []
    self.libraryCompetitions = []
    self.libraryVenues = []
    self.librarySchedules = []
    self.librarySavedMatches = []
    self.localSavedMatches = []
    self.newMatch = Match()
  }

  // Convenience initializers to preserve previous call sites
  @MainActor
  public convenience init(
    haptics: HapticsProviding = NoopHaptics(),
    lifecycleHaptics: MatchLifecycleHapticsProviding = NoopMatchLifecycleHaptics(),
    backgroundRuntime: BackgroundRuntimeManaging? = nil,
    connectivity: ConnectivitySyncProviding? = nil)
  {
    self.init(
      history: MatchHistoryService(),
      penaltyManager: PenaltyManager(),
      haptics: haptics,
      lifecycleHaptics: lifecycleHaptics,
      connectivity: connectivity,
      backgroundRuntimeManager: backgroundRuntime,
      activeMatchSessionStore: nil)
  }

  // MARK: - Match Management

  public func createMatch() {
    // Ensure we start from a clean slate when beginning a new match. This clears any
    // lingering events, timers, and flags from the previous session (e.g. after
    // finalizeMatch) so the new match does not inherit old state.
    self.resetMatch()

    self.currentMatch = self.newMatch
    self.localSavedMatches.append(self.newMatch)
    self.refreshSavedMatches()
    self.newMatch = Match()
    self.applyDefaultTeamsIfNeeded()
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func selectMatch(_ match: Match) {
    self.currentMatch = match
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  // MARK: - Library Integration

  public func updateLibrary(with snapshot: MatchLibrarySnapshot) {
    self.libraryTeams = snapshot.teams.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
    self.libraryCompetitions = snapshot.competitions.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
    self.libraryVenues = snapshot.venues.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
    self.librarySchedules = snapshot.schedules.sorted { $0.kickoff < $1.kickoff }

    // Upcoming/in-progress filter for watch "Select Match" list
    // - Show scheduled or in-progress fixtures (live ones stay visible for quick mirror/controls)
    // - Exclude completed/canceled
    // - Exclude stale past kickoffs; allow a small grace window to avoid race conditions
    let now = Date()
    let graceSeconds: TimeInterval = 10 * 60 // 10-minute grace
    let upcomingScheduled = self.librarySchedules.filter { schedule in
      let status = self.decodeScheduleStatus(schedule.statusRaw)
      let isEligibleStatus: Bool = (status == .scheduled || status == .inProgress)
      return isEligibleStatus && schedule.kickoff >= now.addingTimeInterval(-graceSeconds)
    }

    self.librarySavedMatches = upcomingScheduled.map { schedule in
      var match = Match(
        id: schedule.id, // Use schedule.id as match.id for watch display/selection
        scheduledMatchId: schedule.id, // Also link to schedule for status updates
        homeTeam: schedule.homeName,
        awayTeam: schedule.awayName)
      match.homeTeamId = schedule.homeTeamId
      match.awayTeamId = schedule.awayTeamId
      match.homeMatchSheet = schedule.homeMatchSheet?.normalized()
      match.awayMatchSheet = schedule.awayMatchSheet?.normalized()
      match.startTime = schedule.kickoff
      match.competitionName = schedule.competitionName
      match.venueName = schedule.venueName
      return match
    }

    self.refreshSavedMatches()
    self.applyDefaultTeamsIfNeeded()
  }

  /// Refreshes the current live match with the latest schedule-owned identity
  /// and frozen participant snapshots before kickoff.
  public func refreshCurrentMatchScheduleContext(
    homeTeam: String,
    awayTeam: String,
    homeTeamId: UUID?,
    awayTeamId: UUID?,
    homeMatchSheet: ScheduledMatchSheet?,
    awayMatchSheet: ScheduledMatchSheet?)
  {
    guard var currentMatch else { return }
    currentMatch.homeTeam = homeTeam
    currentMatch.awayTeam = awayTeam
    currentMatch.homeTeamId = homeTeamId
    currentMatch.awayTeamId = awayTeamId
    currentMatch.homeMatchSheet = homeMatchSheet?.normalized()
    currentMatch.awayMatchSheet = awayMatchSheet?.normalized()
    self.currentMatch = currentMatch
  }

  private func refreshSavedMatches() {
    let libraryIds = Set(librarySavedMatches.map(\.id))
    let uniqueLocal = self.localSavedMatches.filter { libraryIds.contains($0.id) == false }
    let combined = self.librarySavedMatches + uniqueLocal
    self.savedMatches = combined.sorted { lhs, rhs in
      switch (lhs.startTime, rhs.startTime) {
      case let (lhsDate?, rhsDate?):
        lhsDate < rhsDate
      case (nil, .some):
        false
      case (.some, nil):
        true
      default:
        lhs.id.uuidString < rhs.id.uuidString
      }
    }
  }

  private func applyDefaultTeamsIfNeeded(force: Bool = false) {
    var updatedMatch = self.newMatch

    if force || self.newMatch.homeTeam == "HOM" {
      if let firstTeam = libraryTeams.first {
        updatedMatch.homeTeam = firstTeam.name
        updatedMatch.homeTeamId = firstTeam.id
        self.homeTeam = firstTeam.name
      } else if force {
        self.homeTeam = updatedMatch.homeTeam
      }
    }

    if force || self.newMatch.awayTeam == "AWA" {
      if let awayCandidate = libraryTeams.dropFirst().first {
        updatedMatch.awayTeam = awayCandidate.name
        updatedMatch.awayTeamId = awayCandidate.id
        self.awayTeam = awayCandidate.name
      } else if force, let firstTeam = libraryTeams.first {
        updatedMatch.awayTeam = firstTeam.name
        updatedMatch.awayTeamId = firstTeam.id
        self.awayTeam = firstTeam.name
      } else if force {
        self.awayTeam = updatedMatch.awayTeam
      }
    }

    self.newMatch = updatedMatch
  }

  private func decodeScheduleStatus(_ raw: String) -> LibraryScheduleStatus {
    switch raw.lowercased() {
    case "in_progress":
      .inProgress
    case "completed":
      .completed
    case "canceled":
      .canceled
    default:
      .scheduled
    }
  }

  // MARK: - Timer Control

  public func startMatch() {
    guard self.currentMatch != nil else { return }

    if !self.isMatchInProgress {
      self.lifecycleHaptics.cancelPendingPlayback()
      self.pendingPeriodBoundaryDecision = nil
      self.isMatchInProgress = true
      self.isPaused = false
      self.waitingForMatchStart = false
      if var m = currentMatch {
        m.startTime = Date()
        self.currentMatch = m
      }
      if let match = currentMatch {
        // If this match originated from a schedule, mark the schedule in progress.
        if let scheduledId = match.scheduledMatchId {
          Task { @MainActor in
            if let updater = scheduleStatusUpdater {
              try? await updater.markScheduleInProgress(scheduledId: scheduledId)
            } else {
              // On watchOS, bridge to iOS via connectivity if available.
              (self.connectivity as? ConnectivitySyncProvidingExtended)?
                .sendScheduleStatusUpdate(
                  scheduledId: scheduledId,
                  status: "in_progress")
            }
          }
        }
        self.periodTimeRemaining = self.timerManager.configureInitialPeriodLabel(
          match: match,
          currentPeriod: self.currentPeriod)
      }
      self.stoppageTimer?.invalidate(); self.stoppageTimer = nil
      self.timerManager.resetForNewPeriod()
      self.stoppageTime = 0
      self.stoppageStartTime = nil
      self.isInStoppage = false
      self.formattedStoppageTime = "00:00"

      self.recordMatchEvent(.kickOff)
      self.recordMatchEvent(.periodStart(self.currentPeriod))

      if let match = currentMatch {
        let periodAtStart = self.currentPeriod
        self.timerManager.startPeriod(
          match: match,
          currentPeriod: self.currentPeriod,
          onTick: { [weak self] snap in
            guard let self else { return }
            self.matchTime = snap.matchTime
            self.periodTime = snap.periodTime
            self.periodTimeRemaining = snap.periodTimeRemaining
            self.formattedStoppageTime = snap.formattedStoppageTime
            self.isInStoppage = snap.isInStoppage
          },
          onPeriodEnd: { [weak self] in
            self?.endPeriod(expectedPeriod: periodAtStart)
          })
      }
      self.syncRuntimeSession(inactiveReason: .cancelled)
    }
  }

  public func pauseMatch() {
    self.isPaused = true
    self.timerManager.pause { [weak self] snap in
      guard let self else { return }
      // Ensure the elapsed match time continues to reflect current time while paused
      self.matchTime = snap.matchTime
      self.formattedStoppageTime = snap.formattedStoppageTime
      self.isInStoppage = snap.isInStoppage
    }
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func resumeMatch() {
    self.isPaused = false
    self.timerManager.resume { [weak self] snap in
      guard let self else { return }
      self.matchTime = snap.matchTime
      self.periodTime = snap.periodTime
      self.periodTimeRemaining = snap.periodTimeRemaining
      self.formattedStoppageTime = snap.formattedStoppageTime
      self.isInStoppage = snap.isInStoppage
    }
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  // MARK: - Stoppage While Running (faces may use these)

  public func beginStoppage() {
    // Do not change isPaused; keep main period/elapsed timers running
    self.timerManager.beginStoppageWhileRunning { [weak self] snap in
      guard let self else { return }
      self.formattedStoppageTime = snap.formattedStoppageTime
      self.isInStoppage = snap.isInStoppage
    }
  }

  public func endStoppage() {
    self.timerManager.endStoppageWhileRunning { [weak self] snap in
      guard let self else { return }
      self.formattedStoppageTime = snap.formattedStoppageTime
      self.isInStoppage = snap.isInStoppage
    }
  }

  public func startNextPeriod() {
    self.lifecycleHaptics.cancelPendingPlayback()
    self.recordPeriodEndIfNeeded(for: self.currentPeriod)
    self.pendingPeriodBoundaryDecision = nil
    self.currentPeriod += 1
    self.isHalfTime = false

    self.timerManager.resetForNewPeriod()
    self.stoppageTime = 0
    self.stoppageStartTime = nil
    self.isInStoppage = false
    self.formattedStoppageTime = "00:00"

    self.recordMatchEvent(.periodStart(self.currentPeriod))

    if let match = currentMatch {
      let periodAtStart = self.currentPeriod
      self.periodTimeRemaining = self.timerManager.configureInitialPeriodLabel(
        match: match,
        currentPeriod: self.currentPeriod)
      self.timerManager.startPeriod(
        match: match,
        currentPeriod: self.currentPeriod,
        onTick: { [weak self] snap in
          guard let self else { return }
          self.matchTime = snap.matchTime
          self.periodTime = snap.periodTime
          self.periodTimeRemaining = snap.periodTimeRemaining
          self.formattedStoppageTime = snap.formattedStoppageTime
          self.isInStoppage = snap.isInStoppage
        },
        onPeriodEnd: { [weak self] in
          self?.endPeriod(expectedPeriod: periodAtStart)
        })
    }
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func startHalfTime() {
    guard let match = currentMatch else { return }
    self.lifecycleHaptics.cancelPendingPlayback()
    self.pendingPeriodBoundaryDecision = nil
    self.isHalfTime = true
    self.timerManager.startHalfTime(match: match) { [weak self] elapsed in
      self?.halfTimeElapsed = elapsed
    }
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  private func endPeriod(expectedPeriod: Int) {
    // Timer callbacks are dispatched asynchronously and may arrive after manual
    // transitions. Ignore stale callbacks once match state has moved on.
    guard self.isMatchInProgress, !self.isHalfTime, !self.isFullTime else { return }
    guard self.currentPeriod == expectedPeriod else { return }
    guard let match = self.currentMatch else { return }
    guard self.pendingPeriodBoundaryDecision == nil else { return }
    guard let boundaryDecision = self.makePendingPeriodBoundaryDecision(
      for: expectedPeriod,
      match: match)
    else { return }

    self.pendingPeriodBoundaryDecision = boundaryDecision
    self.isMatchInProgress = false
    self.isPaused = false
    self.isHalfTime = false
    self.isInStoppage = true
    self.waitingForHalfTimeStart = false
    self.waitingForSecondHalfStart = false
    self.waitingForET1Start = false
    self.waitingForET2Start = false
    self.waitingForPenaltiesStart = false
    self.timerManager.enterPeriodBoundaryOverrun { [weak self] snap in
      guard let self else { return }
      self.matchTime = snap.matchTime
      self.formattedStoppageTime = snap.formattedStoppageTime
      self.isInStoppage = snap.isInStoppage
    }
    self.syncRuntimeSession(inactiveReason: .cancelled)
    self.lifecycleHaptics.play(.periodBoundaryReached)
  }

  @discardableResult
  private func recordPeriodEndIfNeeded(for period: Int) -> Bool {
    guard self.hasRecordedPeriodEnd(for: period) == false else { return false }
    self.recordMatchEvent(.periodEnd(period))
    return true
  }

  private func hasRecordedPeriodEnd(for period: Int) -> Bool {
    for event in self.matchEvents.reversed() {
      switch event.eventType {
      case let .periodEnd(recordedPeriod):
        if recordedPeriod == period { return true }
      case let .periodStart(startedPeriod):
        if startedPeriod == period { return false }
      default:
        continue
      }
    }
    return false
  }

  private func makePendingPeriodBoundaryDecision(
    for period: Int,
    match: Match)
    -> PendingPeriodBoundaryDecision?
  {
    let regularPeriods = max(1, match.numberOfPeriods)

    switch period {
    case 1 where regularPeriods > 1:
      return .firstHalf
    case regularPeriods:
      return .secondHalf
    case regularPeriods + 1 where match.hasExtraTime:
      return .extraTimeFirstHalf
    case regularPeriods + 2 where match.hasExtraTime:
      return .extraTimeSecondHalf
    default:
      return nil
    }
  }

  private func runtimePhaseLabel(for decision: PendingPeriodBoundaryDecision) -> String {
    switch decision {
    case .firstHalf:
      return "pending-period-end-first-half"
    case .secondHalf:
      return "pending-period-end-second-half"
    case .extraTimeFirstHalf:
      return "pending-period-end-et1"
    case .extraTimeSecondHalf:
      return "pending-period-end-et2"
    }
  }

  private func endHalfTime() {
    self.endHalfTimeManually()
  }

  private func endMatch() {
    self.pendingPeriodBoundaryDecision = nil
    self.isMatchInProgress = false
    self.isPaused = false
    self.isFullTime = true
    self.timerManager.stopAll()
    self.timer = nil
    self.stoppageTimer = nil
    self.pendingConfirmation = nil
    self.syncRuntimeSession(inactiveReason: .completed)
  }

  // MARK: - Match Statistics

  public func updateScore(isHome: Bool, increment: Bool = true) {
    guard var match = currentMatch else { return }
    if isHome {
      match.homeScore += increment ? 1 : -1
    } else {
      match.awayScore += increment ? 1 : -1
    }
    self.currentMatch = match
    self.persistActiveMatchSessionIfNeeded()
  }

  public func addCard(isHome: Bool, isYellow: Bool) {
    guard var match = currentMatch else { return }
    if isHome {
      if isYellow { match.homeYellowCards += 1 } else { match.homeRedCards += 1 }
    } else {
      if isYellow { match.awayYellowCards += 1 } else { match.awayRedCards += 1 }
    }
    self.currentMatch = match
    self.persistActiveMatchSessionIfNeeded()
  }

  public func addSubstitution(isHome: Bool) {
    guard var match = currentMatch else { return }
    if isHome { match.homeSubs += 1 } else { match.awaySubs += 1 }
    self.currentMatch = match
    self.persistActiveMatchSessionIfNeeded()
  }

  private func revertGoal(for team: TeamSide) {
    guard var match = currentMatch else { return }
    if team == .home {
      match.homeScore = max(0, match.homeScore - 1)
    } else {
      match.awayScore = max(0, match.awayScore - 1)
    }
    self.currentMatch = match
    self.persistActiveMatchSessionIfNeeded()
  }

  private func revertCard(for team: TeamSide, cardType: CardDetails.CardType) {
    guard var match = currentMatch else { return }
    switch (team, cardType) {
    case (.home, .yellow):
      match.homeYellowCards = max(0, match.homeYellowCards - 1)
    case (.home, .red):
      match.homeRedCards = max(0, match.homeRedCards - 1)
    case (.away, .yellow):
      match.awayYellowCards = max(0, match.awayYellowCards - 1)
    case (.away, .red):
      match.awayRedCards = max(0, match.awayRedCards - 1)
    }
    self.currentMatch = match
    self.persistActiveMatchSessionIfNeeded()
  }

  private func revertSubstitution(for team: TeamSide) {
    guard var match = currentMatch else { return }
    if team == .home {
      match.homeSubs = max(0, match.homeSubs - 1)
    } else {
      match.awaySubs = max(0, match.awaySubs - 1)
    }
    self.currentMatch = match
    self.persistActiveMatchSessionIfNeeded()
  }

  private func setPendingConfirmationIfNeeded(for event: MatchEventRecord) {
    guard self.shouldConfirm(event: event) else { return }
    self.pendingConfirmation = MatchEventConfirmation(event: event)
  }

  private func shouldConfirm(event: MatchEventRecord) -> Bool {
    switch event.eventType {
    case .goal, .card, .substitution:
      true
    default:
      false
    }
  }

  private func isUndoable(_ event: MatchEventRecord) -> Bool {
    switch event.eventType {
    case .goal, .card, .substitution, .penaltyAttempt:
      true
    default:
      false
    }
  }

  // MARK: - Configuration Helpers

  public struct MatchSettings: Equatable, Sendable {
    public let durationMinutes: Int
    public let periods: Int
    public let halfTimeLengthMinutes: Int
    public let hasExtraTime: Bool
    public let hasPenalties: Bool
    public let extraTimeHalfLengthMinutes: Int
    public let penaltyRounds: Int

    public init(
      durationMinutes: Int,
      periods: Int,
      halfTimeLengthMinutes: Int,
      hasExtraTime: Bool,
      hasPenalties: Bool,
      extraTimeHalfLengthMinutes: Int,
      penaltyRounds: Int)
    {
      self.durationMinutes = durationMinutes
      self.periods = periods
      self.halfTimeLengthMinutes = halfTimeLengthMinutes
      self.hasExtraTime = hasExtraTime
      self.hasPenalties = hasPenalties
      self.extraTimeHalfLengthMinutes = extraTimeHalfLengthMinutes
      self.penaltyRounds = penaltyRounds
    }
  }

  public var currentSettings: MatchSettings {
    MatchSettings(
      durationMinutes: self.matchDuration,
      periods: self.numberOfPeriods,
      halfTimeLengthMinutes: self.halfTimeLength,
      hasExtraTime: self.hasExtraTime,
      hasPenalties: self.hasPenalties,
      extraTimeHalfLengthMinutes: self.extraTimeHalfLengthMinutes,
      penaltyRounds: self.penaltyInitialRounds)
  }

  public func configureMatch(
    duration: Int,
    periods: Int,
    halfTimeLength: Int,
    hasExtraTime: Bool,
    hasPenalties: Bool)
  {
    self.newMatch = Match(
      duration: TimeInterval(duration * 60),
      numberOfPeriods: periods,
      halfTimeLength: TimeInterval(halfTimeLength * 60),
      extraTimeHalfLength: TimeInterval(self.extraTimeHalfLengthMinutes * 60),
      hasExtraTime: hasExtraTime,
      hasPenalties: hasPenalties,
      penaltyInitialRounds: self.penaltyInitialRounds)
    self.currentMatch = self.newMatch
    self.waitingForMatchStart = false
    self.persistActiveMatchSessionIfNeeded()
  }

  /// Applies the current settings to the in-progress match without rebuilding it.
  /// Preserves score, events, and custom team names while updating configuration fields.
  public func applySettingsToCurrentMatch(_ settings: MatchSettings) {
    self.matchDuration = settings.durationMinutes
    self.numberOfPeriods = settings.periods
    self.halfTimeLength = settings.halfTimeLengthMinutes
    self.hasExtraTime = settings.hasExtraTime
    self.hasPenalties = settings.hasPenalties
    self.extraTimeHalfLengthMinutes = settings.extraTimeHalfLengthMinutes
    self.penaltyInitialRounds = settings.penaltyRounds

    guard var match = currentMatch else { return }

    match.duration = TimeInterval(settings.durationMinutes * 60)
    match.numberOfPeriods = settings.periods
    match.halfTimeLength = TimeInterval(settings.halfTimeLengthMinutes * 60)
    match.extraTimeHalfLength = TimeInterval(settings.extraTimeHalfLengthMinutes * 60)
    match.hasExtraTime = settings.hasExtraTime
    match.hasPenalties = settings.hasPenalties
    match.penaltyInitialRounds = max(1, settings.penaltyRounds)

    self.currentMatch = match

    if !self.isMatchInProgress {
      self.periodTimeRemaining = self.timerManager.configureInitialPeriodLabel(
        match: match,
        currentPeriod: self.currentPeriod)
    }
    self.persistActiveMatchSessionIfNeeded()
  }

  public func setKickingTeam(_ isHome: Bool) {
    self.homeTeamKickingOff = isHome
    self.persistActiveMatchSessionIfNeeded()
  }
  public func getSecondHalfKickingTeam() -> TeamSide { self.homeTeamKickingOff ? .away : .home }
  public func setKickingTeamET1(_ isHome: Bool) {
    self.homeTeamKickingOffET1 = isHome
    self.persistActiveMatchSessionIfNeeded()
  }
  public func getETSecondHalfKickingTeam() -> TeamSide {
    if let et1 = homeTeamKickingOffET1 { return et1 ? .away : .home }
    return self.getSecondHalfKickingTeam()
  }

  @MainActor
  deinit {
    timerManager.stopAll()
    backgroundRuntimeManager?.end(reason: .reset)
    timer?.invalidate()
    stoppageTimer?.invalidate()
  }
}

// MARK: - Match Event Recording

extension MatchViewModel {
  private func captureMatchEventSnapshot() -> EventSnapshot {
    EventSnapshot(
      timestamp: Date(),
      matchTime: self.matchTime,
      period: self.currentPeriod)
  }

  public func captureEventSnapshotForConfirmation() -> EventSnapshot {
    self.captureMatchEventSnapshot()
  }

  private func makeEventRecord(
    _ eventType: MatchEventType,
    team: TeamSide? = nil,
    details: EventDetails,
    snapshot: EventSnapshot) -> MatchEventRecord
  {
    MatchEventRecord(
      id: UUID(),
      timestamp: snapshot.timestamp,
      actualTime: snapshot.timestamp,
      matchTime: snapshot.matchTime,
      period: snapshot.period,
      eventType: eventType,
      team: team,
      details: details)
  }

  @discardableResult
  public func recordEvent(
    _ eventType: MatchEventType,
    team: TeamSide? = nil,
    details: EventDetails) -> MatchEventRecord
  {
    let event = self.makeEventRecord(
      eventType,
      team: team,
      details: details,
      snapshot: self.captureMatchEventSnapshot())
    self.matchEvents.append(event)
    self.setPendingConfirmationIfNeeded(for: event)
    self.persistActiveMatchSessionIfNeeded()
    return event
  }

  public func recordGoal(
    team: TeamSide,
    goalType: GoalDetails.GoalType,
    playerNumber: Int? = nil,
    playerName: String? = nil)
  {
    let goalDetails = GoalDetails(
      goalType: goalType,
      playerNumber: playerNumber,
      playerName: playerName)
    self.recordEvent(.goal(goalDetails), team: team, details: .goal(goalDetails))
    self.updateScore(isHome: team == .home, increment: true)
  }

  public func recordCard(
    team: TeamSide,
    cardType: CardDetails.CardType,
    recipientType: CardRecipientType,
    playerNumber: Int? = nil,
    playerName: String? = nil,
    officialRole: TeamOfficialRole? = nil,
    reason: String,
    reasonCode: String? = nil,
    reasonTitle: String? = nil)
  {
    let cardDetails = CardDetails(
      cardType: cardType,
      recipientType: recipientType,
      playerNumber: playerNumber,
      playerName: playerName,
      officialRole: officialRole,
      reason: reason,
      reasonCode: reasonCode,
      reasonTitle: reasonTitle)
    self.recordEvent(.card(cardDetails), team: team, details: .card(cardDetails))
    self.addCard(isHome: team == .home, isYellow: cardType == .yellow)
  }

  public func recordSubstitution(
    team: TeamSide,
    playerOut: Int? = nil,
    playerIn: Int? = nil,
    playerOutName: String? = nil,
    playerInName: String? = nil)
  {
    let subDetails = SubstitutionDetails(
      playerOut: playerOut,
      playerIn: playerIn,
      playerOutName: playerOutName,
      playerInName: playerInName)
    self.recordEvent(.substitution(subDetails), team: team, details: .substitution(subDetails))
    self.addSubstitution(isHome: team == .home)
  }

  /// Records multiple substitution events using a single captured match-time snapshot.
  ///
  /// Each substitution is still stored as a normal event so history, sync, and undo
  /// continue to operate on individual substitutions. The event timestamp, displayed
  /// match time, and period are frozen once for the whole batch.
  public func recordSubstitutions(
    team: TeamSide,
    substitutions: [SubstitutionDetails])
  {
    self.recordSubstitutions(
      team: team,
      substitutions: substitutions,
      snapshot: self.captureMatchEventSnapshot())
  }

  public func recordSubstitutions(
    team: TeamSide,
    substitutions: [SubstitutionDetails],
    snapshot: EventSnapshot)
  {
    let filtered = substitutions.filter { substitution in
      substitution.playerOut != nil || substitution.playerIn != nil
        || substitution.playerOutName != nil || substitution.playerInName != nil
    }
    guard filtered.isEmpty == false else { return }
    let events = filtered.map { substitution in
      self.makeEventRecord(
        .substitution(substitution),
        team: team,
        details: .substitution(substitution),
        snapshot: snapshot)
    }

    self.matchEvents.append(contentsOf: events)
    if case .substitution? = self.pendingConfirmation?.event.eventType {
      self.pendingConfirmation = nil
    }

    guard var match = self.currentMatch else {
      self.persistActiveMatchSessionIfNeeded()
      return
    }

    if team == .home {
      match.homeSubs += filtered.count
    } else {
      match.awaySubs += filtered.count
    }

    self.currentMatch = match
    self.persistActiveMatchSessionIfNeeded()
  }

  public func recordMatchEvent(_ eventType: MatchEventType) {
    self.recordEvent(eventType, team: nil, details: .general)
  }

  @MainActor
  public func clearPendingConfirmation(id: UUID? = nil) {
    guard let current = pendingConfirmation else { return }
    if let id, current.id != id { return }
    self.pendingConfirmation = nil
  }

  @discardableResult
  public func undoLastUserEvent() -> Bool {
    guard let index = matchEvents.lastIndex(where: { isUndoable($0) }) else { return false }
    let event = self.matchEvents[index]

    switch event.eventType {
    case .goal:
      guard let team = event.team else { return false }
      self.revertGoal(for: team)
      self.matchEvents.remove(at: index)
    case let .card(details):
      guard let team = event.team else { return false }
      self.revertCard(for: team, cardType: details.cardType)
      self.matchEvents.remove(at: index)
    case .substitution:
      guard let team = event.team else { return false }
      self.revertSubstitution(for: team)
      self.matchEvents.remove(at: index)
    case .penaltyAttempt:
      return self.undoLastPenaltyAttempt()
    default:
      return false
    }

    if self.pendingConfirmation?.event.id == event.id {
      self.pendingConfirmation = nil
    }

    self.haptics.play(.success)
    self.persistActiveMatchSessionIfNeeded()
    return true
  }

  // MARK: - Penalties Flow

  public func beginPenaltiesIfNeeded() {
    guard !self.penaltyManager.isActive else { return }
    self.pendingPeriodBoundaryDecision = nil
    self.waitingForPenaltiesStart = false
    self.isMatchInProgress = false
    self.isPaused = false
    self.timerManager.stopAll()
    self.timer = nil
    self.stoppageTimer = nil
    if let match = currentMatch {
      self.currentPeriod = max(1, match.numberOfPeriods) + (match.hasExtraTime ? 2 : 0) + 1
    } else {
      self.currentPeriod = 5
    }
    self.penaltyStartEventLogged = false
    if let match = currentMatch { self.penaltyManager.setInitialRounds(match.penaltyInitialRounds) }
    self.wirePenaltyCallbacks()
    self.penaltyManager.begin()
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func recordPenaltyAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int? = nil) {
    self.penaltyManager.recordAttempt(team: team, result: result, playerNumber: playerNumber)
    self.persistActiveMatchSessionIfNeeded()
  }

  public func endPenaltiesAndProceed() {
    if self.penaltyManager.isActive { self.penaltyManager.end() }
    self.pendingPeriodBoundaryDecision = nil
    self.waitingForPenaltiesStart = false
    self.isMatchInProgress = false
    self.isPaused = false
    self.timerManager.stopAll()
    self.timer = nil
    self.stoppageTimer = nil
    self.isFullTime = true
    self.penaltyStartEventLogged = false
    self.syncRuntimeSession(inactiveReason: .completed)
  }

  @discardableResult
  public func undoLastPenaltyAttempt() -> Bool {
    guard let undoResult = penaltyManager.undoLastAttempt() else { return false }

    if let index = matchEvents.lastIndex(where: { record in
      if case .penaltyAttempt = record.eventType { return true }
      return false
    }) {
      self.matchEvents.remove(at: index)
    }

    if undoResult.details.result == .scored {
      self.haptics.play(.warning)
    } else {
      self.haptics.play(.tap)
    }

    self.persistActiveMatchSessionIfNeeded()
    return true
  }

  public func swapPenaltyOrder() {
    self.penaltyManager.swapKickingOrder()
    self.haptics.play(.tap)
    self.persistActiveMatchSessionIfNeeded()
  }

  public func setPenaltyFirstKicker(_ team: TeamSide) {
    self.penaltyManager.setFirstKicker(team)
    self.persistActiveMatchSessionIfNeeded()
  }

  @discardableResult
  public func startPenalties(withFirstKicker team: TeamSide) -> Bool {
    self.beginPenaltiesIfNeeded()
    guard self.penaltyManager.isActive else { return false }
    self.penaltyManager.setFirstKicker(team)
    self.persistActiveMatchSessionIfNeeded()
    return true
  }

  // MARK: - Match Management Actions

  public func endCurrentPeriod() {
    self.recordPeriodEndIfNeeded(for: self.currentPeriod)

    guard let match = currentMatch else { return }

    self.pendingPeriodBoundaryDecision = nil
    self.timerManager.stopAll()
    self.timer = nil
    self.stoppageTimer = nil

    if self.currentPeriod == 1, match.numberOfPeriods >= 2 {
      self.isMatchInProgress = false
      self.isPaused = false
      self.waitingForHalfTimeStart = true
    } else if self.currentPeriod < match.numberOfPeriods {
      self.isMatchInProgress = false
      self.isPaused = false
      if self.currentPeriod == 1 { self.waitingForSecondHalfStart = true }
    } else if match.hasExtraTime, self.currentPeriod == match.numberOfPeriods {
      self.isMatchInProgress = false
      self.isPaused = false
      self.waitingForET1Start = true
    } else if match.hasExtraTime, self.currentPeriod == match.numberOfPeriods + 1 {
      self.isMatchInProgress = false
      self.isPaused = false
      self.waitingForET2Start = true
    } else if self.currentPeriod == match.numberOfPeriods + 2 {
      if match.hasPenalties { self.waitingForPenaltiesStart = true } else { self.endMatch() }
    } else {
      self.endMatch()
    }

    if !self.isFullTime {
      self.syncRuntimeSession(inactiveReason: .cancelled)
    }
  }

  public func resetMatch() {
    self.pendingPeriodBoundaryDecision = nil
    self.timerManager.stopAll()
    self.timer = nil
    self.stoppageTimer = nil
    self.currentPeriod = 1
    self.isMatchInProgress = false
    self.isPaused = false
    self.isHalfTime = false
    self.waitingForMatchStart = true
    self.waitingForHalfTimeStart = false
    self.waitingForSecondHalfStart = false
    self.waitingForET1Start = false
    self.waitingForET2Start = false
    self.waitingForPenaltiesStart = false
    self.isFullTime = false
    self.matchCompleted = false
    self.syncRuntimeSession(inactiveReason: .reset)

    if let match = currentMatch {
      self.periodTimeRemaining = self.timerManager.configureInitialPeriodLabel(match: match, currentPeriod: 1)
    } else {
      self.periodTimeRemaining = "45:00"
    }
    self.halfTimeRemaining = "00:00"
    self.halfTimeElapsed = "00:00"
    self.formattedStoppageTime = "00:00"

    if let match = currentMatch {
      var resetMatch = match
      resetMatch.homeScore = 0
      resetMatch.awayScore = 0
      resetMatch.homeYellowCards = 0
      resetMatch.awayYellowCards = 0
      resetMatch.homeRedCards = 0
      resetMatch.awayRedCards = 0
      resetMatch.homeSubs = 0
      resetMatch.awaySubs = 0
      self.currentMatch = resetMatch
    }

    self.matchEvents.removeAll()
    self.homeTeamKickingOffET1 = nil
    self.penaltyManager.end()
    self.penaltyStartEventLogged = false
    self.pendingConfirmation = nil
    self.applyDefaultTeamsIfNeeded()
    self.clearPersistedActiveMatchSession()
  }

  @MainActor
  public func finalizeMatch() {
    self.recordMatchEvent(.matchEnd)

    if let match = currentMatch {
      let snapshot = CompletedMatch(
        match: match,
        events: matchEvents)
      do {
        try self.history.save(snapshot)
        self.connectivity?.sendCompletedMatch(snapshot)
        self.localSavedMatches.removeAll { $0.id == match.id }
        self.refreshSavedMatches()

        // Mark schedule as completed if this was a scheduled match (iOS-only)
        if let scheduledId = match.scheduledMatchId {
          Task { @MainActor in
            if let updater = self.scheduleStatusUpdater {
              try? await updater.markScheduleCompleted(scheduledId: scheduledId)
            } else {
              (self.connectivity as? ConnectivitySyncProvidingExtended)?
                .sendScheduleStatusUpdate(
                  scheduledId: scheduledId,
                  status: "completed")
            }
          }
        }
      } catch {
        self.lastPersistenceError = error.localizedDescription
        self.haptics.play(.failure)
        DispatchQueue.main.async {
          NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
            "error": "history save failed",
            "context": "core.finalizeMatch.save",
          ])
        }
      }
    }
    self.pendingPeriodBoundaryDecision = nil
    self.timerManager.stopAll()
    self.timer = nil
    self.stoppageTimer = nil
    self.isMatchInProgress = false
    self.isPaused = false
    self.isHalfTime = false
    self.waitingForHalfTimeStart = false
    self.waitingForSecondHalfStart = false
    self.isFullTime = true
    self.matchCompleted = true
    self.currentMatch = nil
    self.pendingConfirmation = nil
    self.syncRuntimeSession(inactiveReason: .completed)
  }

  public func abandonMatch() { self.recordMatchEvent(.matchEnd); self.endMatch() }
  public func navigateHome() {
    self.resetMatch()
    self.currentMatch = nil
    self.clearPersistedActiveMatchSession()
  }

  // MARK: - History Bridges

  @MainActor public func loadCompletedMatches() -> [CompletedMatch] { (try? self.history.loadAll()) ?? [] }
  @MainActor public func loadRecentCompletedMatches(limit: Int = 50) -> [CompletedMatch] { self.history
    .loadRecent(limit)
  }

  @MainActor public func latestCompletedMatchSummary() -> CompletedMatchSummary? {
    self.history.loadRecent(1).first.map { CompletedMatchSummary(match: $0) }
  }

  @MainActor public func deleteCompletedMatch(id: UUID) { try? self.history.delete(id: id) }

  // MARK: - Penalty Manager Wiring

  private func wirePenaltyCallbacks() {
    self.penaltyManager.onStart = { [weak self] in
      self?.penaltyStartEventLogged = false
    }
    self.penaltyManager.onAttempt = { [weak self] team, details in
      guard let self else { return }
      if self.penaltyStartEventLogged == false {
        self.recordMatchEvent(.penaltiesStart)
        self.penaltyStartEventLogged = true
      }
      self.recordEvent(.penaltyAttempt(details), team: team, details: .penalty(details))
    }
    self.penaltyManager.onDecided = { _ in }
    self.penaltyManager.onEnd = { [weak self] in self?.recordMatchEvent(.penaltiesEnd) }
  }

  // MARK: - Manual Period Transitions

  public func startHalfTimeManually() {
    guard self.waitingForHalfTimeStart else { return }
    self.lifecycleHaptics.cancelPendingPlayback()
    self.pendingPeriodBoundaryDecision = nil
    self.waitingForHalfTimeStart = false
    self.isHalfTime = true
    self.recordMatchEvent(.halfTime)
    if let match = currentMatch {
      self.timerManager.startHalfTime(match: match) { [weak self] elapsed in
        self?.halfTimeElapsed = elapsed
      }
    }
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func startSecondHalfManually() {
    guard self.waitingForSecondHalfStart else { return }
    self.lifecycleHaptics.cancelPendingPlayback()
    self.pendingPeriodBoundaryDecision = nil
    self.waitingForSecondHalfStart = false
    self.isHalfTime = false
    self.currentPeriod = 2
    self.isMatchInProgress = true
    self.isPaused = false
    self.timerManager.resetForNewPeriod()
    self.stoppageTime = 0
    self.stoppageStartTime = nil
    self.isInStoppage = false
    self.formattedStoppageTime = "00:00"
    self.recordMatchEvent(.periodStart(self.currentPeriod))
    if let match = currentMatch {
      let periodAtStart = self.currentPeriod
      self.periodTimeRemaining = self.timerManager.configureInitialPeriodLabel(
        match: match,
        currentPeriod: self.currentPeriod)
      self.timerManager.startPeriod(
        match: match,
        currentPeriod: self.currentPeriod,
        onTick: { [weak self] snap in
          guard let self else { return }
          self.matchTime = snap.matchTime
          self.periodTime = snap.periodTime
          self.periodTimeRemaining = snap.periodTimeRemaining
          self.formattedStoppageTime = snap.formattedStoppageTime
          self.isInStoppage = snap.isInStoppage
        },
        onPeriodEnd: { [weak self] in
          self?.endPeriod(expectedPeriod: periodAtStart)
        })
    }
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func startExtraTimeFirstHalfManually() {
    guard self.waitingForET1Start, let match = currentMatch else { return }
    self.lifecycleHaptics.cancelPendingPlayback()
    self.pendingPeriodBoundaryDecision = nil
    self.waitingForET1Start = false
    self.isHalfTime = false
    self.currentPeriod = max(1, match.numberOfPeriods) + 1 // ET1
    self.isMatchInProgress = true
    self.isPaused = false
    self.timerManager.resetForNewPeriod()
    self.stoppageTime = 0
    self.stoppageStartTime = nil
    self.isInStoppage = false
    self.formattedStoppageTime = "00:00"
    self.recordMatchEvent(.periodStart(self.currentPeriod))
    self.periodTimeRemaining = self.timerManager.configureInitialPeriodLabel(
      match: match,
      currentPeriod: self.currentPeriod)
    let periodAtStart = self.currentPeriod
    self.timerManager.startPeriod(
      match: match,
      currentPeriod: self.currentPeriod,
      onTick: { [weak self] snap in
        guard let self else { return }
        self.matchTime = snap.matchTime
        self.periodTime = snap.periodTime
        self.periodTimeRemaining = snap.periodTimeRemaining
        self.formattedStoppageTime = snap.formattedStoppageTime
        self.isInStoppage = snap.isInStoppage
      },
      onPeriodEnd: { [weak self] in
        self?.endPeriod(expectedPeriod: periodAtStart)
      })
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func startExtraTimeSecondHalfManually() {
    guard self.waitingForET2Start, let match = currentMatch else { return }
    self.lifecycleHaptics.cancelPendingPlayback()
    self.pendingPeriodBoundaryDecision = nil
    self.waitingForET2Start = false
    self.isHalfTime = false
    self.currentPeriod = max(1, match.numberOfPeriods) + 2 // ET2
    self.isMatchInProgress = true
    self.isPaused = false
    self.timerManager.resetForNewPeriod()
    self.stoppageTime = 0
    self.stoppageStartTime = nil
    self.isInStoppage = false
    self.formattedStoppageTime = "00:00"
    self.recordMatchEvent(.periodStart(self.currentPeriod))
    self.periodTimeRemaining = self.timerManager.configureInitialPeriodLabel(
      match: match,
      currentPeriod: self.currentPeriod)
    let periodAtStart = self.currentPeriod
    self.timerManager.startPeriod(
      match: match,
      currentPeriod: self.currentPeriod,
      onTick: { [weak self] snap in
        guard let self else { return }
        self.matchTime = snap.matchTime
        self.periodTime = snap.periodTime
        self.periodTimeRemaining = snap.periodTimeRemaining
        self.formattedStoppageTime = snap.formattedStoppageTime
        self.isInStoppage = snap.isInStoppage
      },
      onPeriodEnd: { [weak self] in
        self?.endPeriod(expectedPeriod: periodAtStart)
      })
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  public func endHalfTimeManually() {
    self.timerManager.stopHalfTime()
    self.timer = nil
    self.isHalfTime = false
    self.halfTimeRemaining = "00:00"
    self.halfTimeElapsed = "00:00"
    self.waitingForSecondHalfStart = true
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  /// Restores the last persisted unfinished match snapshot if one is available.
  ///
  /// - Returns: `true` when an unfinished snapshot was restored and the caller
  ///   should reroute the UI to the resumed match surface.
  @discardableResult
  public func restorePersistedActiveMatchSessionIfAvailable() -> Bool {
    guard let activeMatchSessionStore else { return false }
    guard let snapshot = try? activeMatchSessionStore.load() else { return false }
    guard snapshot.isUnfinished else {
      self.clearPersistedActiveMatchSession()
      return false
    }
    self.restore(from: snapshot)
    return true
  }

  /// Applies a persisted unfinished-match snapshot and rehydrates the view model
  /// into the exact lifecycle state that was active before interruption.
  ///
  /// - Parameter snapshot: The unfinished-match snapshot to restore.
  public func restore(from snapshot: ActiveMatchSessionSnapshot) {
    guard snapshot.isUnfinished else {
      self.clearPersistedActiveMatchSession()
      return
    }

    self.timerManager.stopAll()
    self.timer = nil
    self.stoppageTimer = nil
    self.pendingConfirmation = nil
    self.lastPersistenceError = nil

    self.currentMatch = snapshot.match
    self.currentPeriod = snapshot.currentPeriod
    self.isMatchInProgress = snapshot.isMatchInProgress
    self.isHalfTime = snapshot.isHalfTime
    self.isPaused = snapshot.isPaused
    self.waitingForMatchStart = snapshot.waitingForMatchStart
    self.waitingForHalfTimeStart = snapshot.waitingForHalfTimeStart
    self.waitingForSecondHalfStart = snapshot.waitingForSecondHalfStart
    self.waitingForET1Start = snapshot.waitingForET1Start
    self.waitingForET2Start = snapshot.waitingForET2Start
    self.waitingForPenaltiesStart = snapshot.waitingForPenaltiesStart
    self.pendingPeriodBoundaryDecision = snapshot.pendingPeriodBoundaryDecision
    self.isFullTime = snapshot.isFullTime
    self.matchCompleted = snapshot.matchCompleted
    self.matchTime = snapshot.displayState.matchTime
    self.periodTime = snapshot.displayState.periodTime
    self.periodTimeRemaining = snapshot.displayState.periodTimeRemaining
    self.halfTimeRemaining = snapshot.displayState.halfTimeRemaining
    self.halfTimeElapsed = snapshot.displayState.halfTimeElapsed
    self.formattedStoppageTime = snapshot.displayState.formattedStoppageTime
    self.isInStoppage = snapshot.isInStoppage
    self.homeTeamKickingOff = snapshot.homeTeamKickingOff
    self.homeTeamKickingOffET1 = snapshot.homeTeamKickingOffET1
    self.matchEvents = snapshot.matchEvents
    self.penaltyStartEventLogged = snapshot.penaltyStartEventLogged
    self.penaltyManager.restore(from: snapshot.penaltyState)
    self.wirePenaltyCallbacks()

    if let match = self.currentMatch,
       self.localSavedMatches.contains(where: { $0.id == match.id }) == false,
       self.librarySavedMatches.contains(where: { $0.id == match.id }) == false
    {
      self.localSavedMatches.append(match)
      self.refreshSavedMatches()
    }

    self.restoreTimerState(from: snapshot)
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  // MARK: - Background Runtime Support

  /// Reconciles workout-backed runtime protection with the current lifecycle
  /// state.
  ///
  /// Watch surfaces call this during scene-phase changes so the runtime
  /// controller can recover, update, or stop the active workout session without
  /// each view starting or ending sessions directly.
  public func reconcileBackgroundRuntimeSession() {
    self.syncRuntimeSession(inactiveReason: .cancelled)
  }

  private func refreshRuntimeSession(with match: Match) {
    self.backgroundRuntimeManager?.begin(
      kind: .match,
      title: self.matchDisplayTitle(for: match),
      metadata: self.matchMetadata(for: match))
  }

  private func syncRuntimeSession(inactiveReason: BackgroundRuntimeEndReason) {
    defer {
      self.persistActiveMatchSessionIfNeeded()
    }

    guard let runtimeManager = self.backgroundRuntimeManager else { return }

    guard self.runtimeProtectionRequired else {
      runtimeManager.end(reason: inactiveReason)
      return
    }

    guard let match = self.currentMatch else {
      runtimeManager.end(reason: inactiveReason)
      return
    }

    self.refreshRuntimeSession(with: match)
    if self.isPaused {
      runtimeManager.notifyPause()
    } else {
      runtimeManager.notifyResume()
    }
  }

  /// Returns whether the current match lifecycle still requires workout-backed
  /// Match Mode protection.
  ///
  /// This scope intentionally includes more than active clock time. It covers
  /// kickoff waiting, paused play, halftime transitions, extra-time transitions,
  /// penalties, and the full-time screen until the referee explicitly completes,
  /// resets, or cancels the unfinished match.
  private var runtimeProtectionRequired: Bool {
    (self.waitingForMatchStart && self.currentMatch != nil) ||
      self.isMatchInProgress ||
      self.isHalfTime ||
      self.waitingForHalfTimeStart ||
      self.waitingForSecondHalfStart ||
      self.waitingForET1Start ||
      self.waitingForET2Start ||
      self.waitingForPenaltiesStart ||
      self.pendingPeriodBoundaryDecision != nil ||
      self.penaltyShootoutActive ||
      (self.isFullTime && self.matchCompleted == false && self.currentMatch != nil)
  }

  /// Labels the current unfinished-match phase for runtime-session metadata and
  /// recovery diagnostics.
  private var runtimePhaseLabel: String {
    if self.penaltyShootoutActive { return "penalties" }
    if self.waitingForPenaltiesStart { return "waiting-penalties" }
    if let pendingPeriodBoundaryDecision {
      return self.runtimePhaseLabel(for: pendingPeriodBoundaryDecision)
    }
    if self.isFullTime && self.matchCompleted == false { return "full-time-pending-completion" }
    if self.isHalfTime { return "halftime" }
    if self.waitingForHalfTimeStart { return "waiting-halftime" }
    if self.waitingForSecondHalfStart { return "waiting-second-half" }
    if self.waitingForET1Start { return "waiting-et1" }
    if self.waitingForET2Start { return "waiting-et2" }
    if self.isMatchInProgress { return "in-play" }
    if self.isFullTime || self.matchCompleted { return "full-time" }
    if self.waitingForMatchStart { return "waiting-kickoff" }
    return "idle"
  }

  private func matchDisplayTitle(for match: Match) -> String {
    let home = match.homeTeam.isEmpty ? "Home" : match.homeTeam
    let away = match.awayTeam.isEmpty ? "Away" : match.awayTeam
    return "\(home) vs \(away)"
  }

  private func matchMetadata(for match: Match) -> [String: String] {
    var data: [String: String] = [
      "matchId": match.id.uuidString,
      "homeTeam": match.homeTeam,
      "awayTeam": match.awayTeam,
    ]
    data["currentPeriod"] = String(self.currentPeriod)
    data["phase"] = self.runtimePhaseLabel
    data["isPaused"] = self.isPaused ? "true" : "false"
    data["runtimeProtectionRequired"] = self.runtimeProtectionRequired ? "true" : "false"
    data["hasExtraTime"] = match.hasExtraTime ? "true" : "false"
    if let pendingPeriodBoundaryDecision {
      data["pendingPeriodBoundaryDecision"] = pendingPeriodBoundaryDecision.rawValue
    }
    return data
  }

  private func restoreTimerState(from snapshot: ActiveMatchSessionSnapshot) {
    guard let match = self.currentMatch else { return }

    if self.pendingPeriodBoundaryDecision != nil {
      self.timerManager.restorePeriodBoundaryOverrun(
        match: match,
        currentPeriod: self.currentPeriod,
        persistenceState: snapshot.timerState,
        onTick: { [weak self] restoredSnapshot in
          guard let self else { return }
          self.matchTime = restoredSnapshot.matchTime
          self.formattedStoppageTime = restoredSnapshot.formattedStoppageTime
          self.isInStoppage = restoredSnapshot.isInStoppage
        })
      return
    }

    if self.isHalfTime {
      self.timerManager.restoreHalfTime(match: match, persistenceState: snapshot.timerState) { [weak self] elapsed in
        self?.halfTimeElapsed = elapsed
      }
      return
    }

    if self.isMatchInProgress || self.isPaused {
      let restoredPeriod = self.currentPeriod
      self.timerManager.restorePeriod(
        match: match,
        currentPeriod: restoredPeriod,
        persistenceState: snapshot.timerState,
        isPaused: self.isPaused,
        onTick: { [weak self] restoredSnapshot in
          guard let self else { return }
          self.matchTime = restoredSnapshot.matchTime
          self.periodTime = restoredSnapshot.periodTime
          self.periodTimeRemaining = restoredSnapshot.periodTimeRemaining
          self.formattedStoppageTime = restoredSnapshot.formattedStoppageTime
          self.isInStoppage = restoredSnapshot.isInStoppage
        },
        onPeriodEnd: { [weak self] in
          self?.endPeriod(expectedPeriod: restoredPeriod)
        })
    }
  }

  private func persistActiveMatchSessionIfNeeded() {
    guard let activeMatchSessionStore else { return }

    guard let snapshot = self.makeActiveMatchSessionSnapshot(), snapshot.isUnfinished else {
      try? activeMatchSessionStore.clear()
      return
    }

    try? activeMatchSessionStore.save(snapshot)
  }

  private func clearPersistedActiveMatchSession() {
    try? self.activeMatchSessionStore?.clear()
  }

  private func makeActiveMatchSessionSnapshot() -> ActiveMatchSessionSnapshot? {
    guard let currentMatch else { return nil }

    return ActiveMatchSessionSnapshot(
      match: currentMatch,
      currentPeriod: self.currentPeriod,
      isMatchInProgress: self.isMatchInProgress,
      isHalfTime: self.isHalfTime,
      isPaused: self.isPaused,
      waitingForMatchStart: self.waitingForMatchStart,
      waitingForHalfTimeStart: self.waitingForHalfTimeStart,
      waitingForSecondHalfStart: self.waitingForSecondHalfStart,
      waitingForET1Start: self.waitingForET1Start,
      waitingForET2Start: self.waitingForET2Start,
      waitingForPenaltiesStart: self.waitingForPenaltiesStart,
      pendingPeriodBoundaryDecision: self.pendingPeriodBoundaryDecision,
      isFullTime: self.isFullTime,
      matchCompleted: self.matchCompleted,
      displayState: ActiveMatchDisplayState(
        matchTime: self.matchTime,
        periodTime: self.periodTime,
        periodTimeRemaining: self.periodTimeRemaining,
        halfTimeRemaining: self.halfTimeRemaining,
        halfTimeElapsed: self.halfTimeElapsed,
        formattedStoppageTime: self.formattedStoppageTime),
      isInStoppage: self.isInStoppage,
      homeTeamKickingOff: self.homeTeamKickingOff,
      homeTeamKickingOffET1: self.homeTeamKickingOffET1,
      matchEvents: self.matchEvents,
      penaltyState: self.penaltyManager.snapshotState(),
      timerState: self.timerManager.persistenceState(),
      penaltyStartEventLogged: self.penaltyStartEventLogged)
  }
}
