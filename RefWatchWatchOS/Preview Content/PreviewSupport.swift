//
//  PreviewSupport.swift
//  RefWatchWatchOS
//
//  Shared helpers for deterministic watchOS previews.
//

import RefWatchCore
import SwiftData
import SwiftUI

#if DEBUG
@MainActor
final class PreviewMatchHistoryStore: MatchHistoryStoring {
  private var matches: [CompletedMatch] = []

  func loadAll() throws -> [CompletedMatch] {
    self.matches
  }

  func save(_ match: CompletedMatch) throws {
    self.matches.append(match)
  }

  func delete(id: UUID) throws {
    self.matches.removeAll { $0.id == id }
  }

  func wipeAll() throws {
    self.matches.removeAll()
  }
}

final class NoopLiveActivityCommandStore: LiveActivityCommandStoring {
  @discardableResult
  func write(_ command: LiveActivityCommand) -> LiveActivityCommandEnvelope {
    LiveActivityCommandEnvelope(command: command)
  }

  func consume() -> LiveActivityCommandEnvelope? {
    nil
  }

  func clear() {}
}

@MainActor
final class NoopMatchLiveActivityPublisher: MatchLiveActivityPublishing {
  func publish(for model: MatchViewModel) {}
  func end() {}
}

private struct PreviewLifecycleScheduledWork: WatchMatchLifecycleScheduledWork {
  func cancel() {}
}

private final class PreviewLifecycleScheduler: WatchMatchLifecycleHapticScheduling {
  @discardableResult
  func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> any WatchMatchLifecycleScheduledWork {
    PreviewLifecycleScheduledWork()
  }
}

private final class PreviewLifecycleDriver: WatchMatchLifecycleHapticDriving {
  func playNotification() {}
}

@MainActor
private final class PreviewMatchRuntimeSessionProvider: MatchRuntimeSessionProviding {
  private(set) var hasActiveSession = false
  private(set) var startedAt: Date?

  func recoverActiveSessionIfPossible() async throws -> Bool {
    false
  }

  func requestAuthorizationIfNeeded() async throws -> Bool {
    true
  }

  func start(title: String?, metadata: [String: String]) async throws {
    self.hasActiveSession = true
    self.startedAt = Date()
  }

  func update(title: String?, metadata: [String: String]) {}

  func stop(reason: BackgroundRuntimeEndReason) async throws {
    self.hasActiveSession = false
    self.startedAt = nil
  }
}

enum WatchPreviewSupport {
  static let defaultTheme = AnyTheme(theme: DefaultTheme())
  static let defaultLayout = WatchLayoutScale(category: .standard)
  static let compactLayout = WatchLayoutScale(category: .compact)
  static let expandedLayout = WatchLayoutScale(category: .expanded)

  static func makeDefaults(
    suiteName: String,
    timerFaceStyle: TimerFaceStyle = .standard,
    countdownEnabled: Bool = true) -> UserDefaults
  {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      fatalError("Failed to create preview defaults suite: \(suiteName)")
    }
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(timerFaceStyle.rawValue, forKey: "timer_face_style")
    defaults.set(countdownEnabled, forKey: "countdown_enabled")
    return defaults
  }

  @MainActor
  static func makeAggregateEnvironment() -> AggregateSyncEnvironment {
    guard let container = try? WatchAggregateContainerFactory.makeContainer(inMemory: true) else {
      fatalError("Failed to create in-memory aggregate container for previews")
    }

    let library = WatchAggregateLibraryStore(container: container)
    let chunk = WatchAggregateSnapshotChunkStore(container: container)
    let delta = WatchAggregateDeltaOutboxStore(container: container)
    let coordinator = WatchAggregateSyncCoordinator(
      libraryStore: library,
      chunkStore: chunk,
      deltaStore: delta)
    let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)

    return AggregateSyncEnvironment(
      libraryStore: library,
      chunkStore: chunk,
      deltaStore: delta,
      coordinator: coordinator,
      connectivity: connectivity)
  }

  @MainActor
  static func makeCommandHandler() -> LiveActivityCommandHandler {
    LiveActivityCommandHandler(store: NoopLiveActivityCommandStore())
  }

  @MainActor
  static func makeLiveActivityPublisher() -> any MatchLiveActivityPublishing {
    NoopMatchLiveActivityPublisher()
  }

  @MainActor
  static func makeRuntimeController() -> BackgroundRuntimeSessionController {
    BackgroundRuntimeSessionController(provider: PreviewMatchRuntimeSessionProvider())
  }

  @MainActor
  static func makeLifecycleHaptics(
    activeCue: MatchLifecycleHapticCue? = nil) -> WatchMatchLifecycleHaptics
  {
    let haptics = WatchMatchLifecycleHaptics(
      scheduler: PreviewLifecycleScheduler(),
      driver: PreviewLifecycleDriver())
    if let activeCue {
      haptics.play(activeCue)
    }
    return haptics
  }
}

extension View {
  func watchPreviewChrome(
    layout: WatchLayoutScale = WatchPreviewSupport.defaultLayout) -> some View
  {
    self
      .environment(\.theme, WatchPreviewSupport.defaultTheme)
      .watchLayoutScale(layout)
      .hapticsProvider(NoopHaptics())
  }

  func watchFacePreviewSurface(
    layout: WatchLayoutScale = WatchPreviewSupport.defaultLayout) -> some View
  {
    let side: CGFloat = switch layout.category {
    case .compact:
      176
    case .standard:
      198
    case .expanded:
      218
    }

    return self
      .frame(width: side, height: side)
      .background(Color.black)
      .watchPreviewChrome(layout: layout)
  }
}

@MainActor
extension MatchViewModel {
  static func previewRunningRegulation() -> MatchViewModel {
    let viewModel = self.makePreviewBaseMatchViewModel()
    self.applyTeams(home: "ARS", away: "MCI", to: viewModel)

    viewModel.currentPeriod = 1
    viewModel.waitingForMatchStart = false
    viewModel.isMatchInProgress = true
    viewModel.isPaused = false
    viewModel.matchTime = "37:42"
    viewModel.periodTime = "37:42"
    viewModel.periodTimeRemaining = "07:18"
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    return viewModel
  }

  static func previewExpiredBoundary(
    stoppage: Bool = false,
    finalRegulation: Bool = false) -> MatchViewModel
  {
    let viewModel = self.makePreviewBaseMatchViewModel()
    self.applyTeams(home: "ARS", away: "MCI", to: viewModel)

    viewModel.currentPeriod = finalRegulation ? 2 : 1
    viewModel.waitingForMatchStart = false
    viewModel.isMatchInProgress = true
    viewModel.isPaused = false
    viewModel.pendingPeriodBoundaryDecision = finalRegulation ? .secondHalf : .firstHalf
    viewModel.matchTime = stoppage ? (finalRegulation ? "92:14" : "46:24") : (finalRegulation ? "90:00" : "45:00")
    viewModel.periodTime = viewModel.matchTime
    viewModel.periodTimeRemaining = "00:00"
    viewModel.isInStoppage = stoppage
    viewModel.formattedStoppageTime = stoppage ? (finalRegulation ? "02:14" : "01:24") : "00:00"
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    return viewModel
  }

  static func previewWaitingForHalfTimeStart() -> MatchViewModel {
    let viewModel = self.makePreviewBaseMatchViewModel()
    self.applyTeams(home: "ARS", away: "MCI", to: viewModel)

    viewModel.currentPeriod = 1
    viewModel.waitingForMatchStart = false
    viewModel.waitingForHalfTimeStart = true
    viewModel.isMatchInProgress = false
    viewModel.isHalfTime = false
    viewModel.isPaused = false
    viewModel.pendingPeriodBoundaryDecision = nil
    viewModel.matchTime = "45:00"
    viewModel.periodTime = "45:00"
    viewModel.periodTimeRemaining = "00:00"
    viewModel.updateScore(isHome: true, increment: true)
    return viewModel
  }

  static func previewHalfTimeActive() -> MatchViewModel {
    let viewModel = self.makePreviewBaseMatchViewModel()
    self.applyTeams(home: "ARS", away: "MCI", to: viewModel)

    viewModel.currentPeriod = 1
    viewModel.waitingForMatchStart = false
    viewModel.isMatchInProgress = false
    viewModel.isHalfTime = true
    viewModel.isPaused = false
    viewModel.matchTime = "45:00"
    viewModel.periodTime = "45:00"
    viewModel.periodTimeRemaining = "00:00"
    viewModel.halfTimeElapsed = "07:18"
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    return viewModel
  }

  static func previewSecondHalfKickoff() -> MatchViewModel {
    let viewModel = self.makePreviewBaseMatchViewModel()
    self.applyTeams(home: "ARS", away: "MCI", to: viewModel)

    viewModel.currentPeriod = 1
    viewModel.waitingForMatchStart = false
    viewModel.waitingForSecondHalfStart = true
    viewModel.isMatchInProgress = false
    viewModel.isHalfTime = false
    viewModel.matchTime = "45:00"
    viewModel.periodTime = "45:00"
    viewModel.periodTimeRemaining = "00:00"
    viewModel.setKickingTeam(true)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    return viewModel
  }

  static func previewFullTimePendingCompletion() -> MatchViewModel {
    let viewModel = self.makePreviewBaseMatchViewModel()
    self.applyTeams(home: "ARS", away: "MCI", to: viewModel)

    viewModel.currentPeriod = 2
    viewModel.waitingForMatchStart = false
    viewModel.isFullTime = true
    viewModel.matchCompleted = false
    viewModel.isMatchInProgress = false
    viewModel.matchTime = "90:00"
    viewModel.periodTime = "45:00"
    viewModel.periodTimeRemaining = "00:00"
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    return viewModel
  }

  private static func makePreviewBaseMatchViewModel(
    lifecycleHaptics: MatchLifecycleHapticsProviding? = nil,
    backgroundRuntimeManager: BackgroundRuntimeManaging? = nil,
    activeMatchSessionStore: ActiveMatchSessionStoring? = nil) -> MatchViewModel
  {
    let viewModel = MatchViewModel(
      history: PreviewMatchHistoryStore(),
      haptics: NoopHaptics(),
      lifecycleHaptics: lifecycleHaptics ?? NoopMatchLifecycleHaptics(),
      backgroundRuntimeManager: backgroundRuntimeManager ?? NoopBackgroundRuntimeManager(),
      activeMatchSessionStore: activeMatchSessionStore ?? NoopActiveMatchSessionStore())
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    return viewModel
  }

  fileprivate static func applyTeams(home: String, away: String, to viewModel: MatchViewModel) {
    viewModel.homeTeam = home
    viewModel.awayTeam = away
    viewModel.refreshCurrentMatchScheduleContext(
      homeTeam: home,
      awayTeam: away,
      homeTeamId: nil,
      awayTeamId: nil,
      homeMatchSheet: nil,
      awayMatchSheet: nil)
  }
}

@MainActor
struct MatchRootPreviewConfiguration {
  let backgroundRuntimeController: BackgroundRuntimeSessionController
  let lifecycleHaptics: WatchMatchLifecycleHaptics
  let matchViewModel: MatchViewModel
  let settingsViewModel: SettingsViewModel
  let lifecycle: MatchLifecycleCoordinator
  let livePublisher: any MatchLiveActivityPublishing
  let commandHandler: LiveActivityCommandHandler
}

@MainActor
extension MatchRootPreviewConfiguration {
  static func idle() -> MatchRootPreviewConfiguration {
    let runtimeController = WatchPreviewSupport.makeRuntimeController()
    let lifecycleHaptics = WatchPreviewSupport.makeLifecycleHaptics()
    let matchViewModel = MatchViewModel(
      history: PreviewMatchHistoryStore(),
      haptics: NoopHaptics(),
      lifecycleHaptics: lifecycleHaptics,
      backgroundRuntimeManager: runtimeController,
      activeMatchSessionStore: NoopActiveMatchSessionStore())

    return MatchRootPreviewConfiguration(
      backgroundRuntimeController: runtimeController,
      lifecycleHaptics: lifecycleHaptics,
      matchViewModel: matchViewModel,
      settingsViewModel: SettingsViewModel(),
      lifecycle: MatchLifecycleCoordinator(),
      livePublisher: WatchPreviewSupport.makeLiveActivityPublisher(),
      commandHandler: WatchPreviewSupport.makeCommandHandler())
  }

  static func endOfHalfAlertVisible() -> MatchRootPreviewConfiguration {
    let runtimeController = WatchPreviewSupport.makeRuntimeController()
    let lifecycleHaptics = WatchPreviewSupport.makeLifecycleHaptics(activeCue: .periodBoundaryReached(.firstHalf))
    let matchViewModel = MatchViewModel(
      history: PreviewMatchHistoryStore(),
      haptics: NoopHaptics(),
      lifecycleHaptics: lifecycleHaptics,
      backgroundRuntimeManager: runtimeController,
      activeMatchSessionStore: NoopActiveMatchSessionStore())
    matchViewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    MatchViewModel.applyTeams(home: "ARS", away: "MCI", to: matchViewModel)
    matchViewModel.currentPeriod = 1
    matchViewModel.waitingForMatchStart = false
    matchViewModel.isMatchInProgress = true
    matchViewModel.pendingPeriodBoundaryDecision = .firstHalf
    matchViewModel.matchTime = "45:00"
    matchViewModel.periodTime = "45:00"
    matchViewModel.periodTimeRemaining = "00:00"
    matchViewModel.updateScore(isHome: true, increment: true)
    matchViewModel.updateScore(isHome: false, increment: true)

    let lifecycle = MatchLifecycleCoordinator()
    lifecycle.goToSetup()

    return MatchRootPreviewConfiguration(
      backgroundRuntimeController: runtimeController,
      lifecycleHaptics: lifecycleHaptics,
      matchViewModel: matchViewModel,
      settingsViewModel: SettingsViewModel(),
      lifecycle: lifecycle,
      livePublisher: WatchPreviewSupport.makeLiveActivityPublisher(),
      commandHandler: WatchPreviewSupport.makeCommandHandler())
  }

  static func halfTimeOverAlertVisible() -> MatchRootPreviewConfiguration {
    let runtimeController = WatchPreviewSupport.makeRuntimeController()
    let lifecycleHaptics = WatchPreviewSupport.makeLifecycleHaptics(activeCue: .halftimeDurationReached)
    let matchViewModel = MatchViewModel(
      history: PreviewMatchHistoryStore(),
      haptics: NoopHaptics(),
      lifecycleHaptics: lifecycleHaptics,
      backgroundRuntimeManager: runtimeController,
      activeMatchSessionStore: NoopActiveMatchSessionStore())
    matchViewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    MatchViewModel.applyTeams(home: "ARS", away: "MCI", to: matchViewModel)
    matchViewModel.currentPeriod = 1
    matchViewModel.waitingForMatchStart = false
    matchViewModel.isHalfTime = true
    matchViewModel.halfTimeElapsed = "15:00"
    matchViewModel.matchTime = "45:00"
    matchViewModel.periodTime = "45:00"
    matchViewModel.periodTimeRemaining = "00:00"
    matchViewModel.updateScore(isHome: true, increment: true)
    matchViewModel.updateScore(isHome: false, increment: true)

    let lifecycle = MatchLifecycleCoordinator()
    lifecycle.goToSetup()

    return MatchRootPreviewConfiguration(
      backgroundRuntimeController: runtimeController,
      lifecycleHaptics: lifecycleHaptics,
      matchViewModel: matchViewModel,
      settingsViewModel: SettingsViewModel(),
      lifecycle: lifecycle,
      livePublisher: WatchPreviewSupport.makeLiveActivityPublisher(),
      commandHandler: WatchPreviewSupport.makeCommandHandler())
  }
}
#endif
