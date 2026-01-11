import Foundation
import RefWatchCore
import RefWorkoutCore

/// Domain-specific errors for workout operations
enum WorkoutError: LocalizedError, Equatable {
  case authorizationDenied
  case healthDataUnavailable
  case authorizationRequestFailed
  case sessionNotFound
  case sessionStartFailed(reason: String)
  case sessionEndFailed(reason: String)
  case collectionFailed(reason: String)
  case sessionFinishFailed(reason: String)
  case historyPersistenceFailed(reason: String)
  case presetLoadFailed(reason: String)

  var errorDescription: String? {
    switch self {
    case .authorizationDenied:
      "HealthKit access denied. Manage workout permissions on your paired iPhone."
    case .healthDataUnavailable:
      "HealthKit is not available on this device."
    case .authorizationRequestFailed:
      "Failed to request HealthKit authorization. Please try again."
    case .sessionNotFound:
      "Workout session not found. Please try starting a new workout."
    case let .sessionStartFailed(reason):
      "Failed to start workout: \(reason)"
    case let .sessionEndFailed(reason):
      "Failed to end workout: \(reason)"
    case let .collectionFailed(reason):
      "Failed to collect workout data: \(reason)"
    case let .sessionFinishFailed(reason):
      "Failed to finish saving workout data: \(reason)"
    case let .historyPersistenceFailed(reason):
      "Workout ended but couldn't save to history: \(reason)"
    case let .presetLoadFailed(reason):
      "Failed to load workout presets: \(reason)"
    }
  }

  var recoveryAction: String? {
    switch self {
    case .authorizationDenied:
      "On your iPhone, open Settings > Health > Data Access & Devices > RefWatch to enable workout permissions."
    case .healthDataUnavailable:
      "HealthKit is not supported on this device. Workout features may be limited."
    case .authorizationRequestFailed:
      "Try requesting permissions again or restart the app."
    case .sessionNotFound:
      "Start a new workout session."
    case .sessionStartFailed:
      "Try starting the workout again or restart the app."
    case .sessionEndFailed:
      "The workout ended but may not have been saved properly."
    case .collectionFailed:
      "Try ending the workout again or restart the app."
    case .sessionFinishFailed:
      "Your workout data may be incomplete. Try syncing later."
    case .historyPersistenceFailed:
      "Your workout data was recorded but couldn't be saved. Try syncing later."
    case .presetLoadFailed:
      "Using default presets. Check your connection and try again."
    }
  }
}

struct WorkoutSelectionDwellConfiguration {
  let dwellDuration: TimeInterval
  let velocityThreshold: Double

  static let standard = WorkoutSelectionDwellConfiguration(dwellDuration: 1.25, velocityThreshold: 0.15)
}

enum WorkoutSelectionDwellState: Equatable {
  case idle
  case pending(itemID: WorkoutSelectionItem.ID, startedAt: Date)
  case locked(itemID: WorkoutSelectionItem.ID, completedAt: Date)
}

enum WorkoutPresentationState: Equatable {
  case list
  case preview(WorkoutSelectionItem)
  case starting(WorkoutSelectionItem)
  case session(WorkoutSession)
  case error(WorkoutSelectionItem, WorkoutError)
}

struct WorkoutSelectionItem: Identifiable, Equatable {
  enum ID: Hashable {
    case authorization
    case lastCompleted(UUID)
    case quickStart(WorkoutKind)
    case preset(UUID)
    case emptyPresets
  }

  enum Content: Equatable {
    case authorization(status: WorkoutAuthorizationStatus, diagnostics: [WorkoutAuthorizationMetric])
    case lastCompleted(session: WorkoutSession)
    case quickStart(kind: WorkoutKind)
    case preset(preset: WorkoutPreset)
    case emptyPresets
  }

  enum Interaction: Equatable {
    case preview
    case informational
  }

  let id: ID
  let content: Content

  var interaction: Interaction {
    switch self.content {
    case .authorization, .emptyPresets:
      .informational
    case .lastCompleted, .quickStart, .preset:
      .preview
    }
  }

  var allowsDwell: Bool {
    self.interaction == .preview
  }

  var title: String {
    switch self.content {
    case let .authorization(status, _):
      switch status.state {
      case .notDetermined:
        "Grant on iPhone"
      case .denied:
        "Access Denied on iPhone"
      case .limited:
        "Limited Access on iPhone"
      case .authorized:
        "Manage on iPhone"
      }
    case let .lastCompleted(session):
      session.title
    case let .quickStart(kind):
      kind.displayName
    case let .preset(preset):
      preset.title
    case .emptyPresets:
      "Sync Workouts"
    }
  }

  var subtitle: String? {
    switch self.content {
    case let .authorization(status, _):
      WorkoutSelectionItem.authorizationMessage(for: status)
    case let .lastCompleted(session):
      WorkoutSelectionItem.summary(for: session)
    case let .quickStart(kind):
      WorkoutSelectionItem.quickStartSubtitle(for: kind)
    case let .preset(preset):
      WorkoutSelectionItem.presetSummary(preset)
    case .emptyPresets:
      "Create workouts on iPhone"
    }
  }

  var iconSystemName: String? {
    switch self.content {
    case .authorization:
      "heart.text.square"
    case let .lastCompleted(session):
      WorkoutSelectionItem.icon(for: session.kind)
    case let .quickStart(kind):
      WorkoutSelectionItem.icon(for: kind)
    case let .preset(preset):
      WorkoutSelectionItem.icon(for: preset.kind)
    case .emptyPresets:
      "iphone"
    }
  }

  var diagnosticsDescription: String? {
    switch self.content {
    case let .authorization(_, diagnostics):
      WorkoutSelectionItem.authorizationDiagnosticsSummary(for: diagnostics)
    default:
      nil
    }
  }

  static func authorizationDiagnosticsSummary(for metrics: [WorkoutAuthorizationMetric]) -> String? {
    guard !metrics.isEmpty else { return nil }
    let names = metrics.map(\.displayName).sorted()
    if names.count == 1 {
      return "Optional metric off: \(names[0])"
    }
    if names.count == 2 {
      return "Optional metrics off: \(names[0]), \(names[1])"
    }
    let remaining = names.count - 2
    return "Optional metrics off: \(names[0]), \(names[1]) +\(remaining)"
  }

  var authorizationStatus: WorkoutAuthorizationStatus? {
    if case let .authorization(status, _) = content {
      return status
    }
    return nil
  }

  var lastCompletedSession: WorkoutSession? {
    if case let .lastCompleted(session) = content {
      return session
    }
    return nil
  }

  var quickStartKind: WorkoutKind? {
    if case let .quickStart(kind) = content {
      return kind
    }
    return nil
  }

  var preset: WorkoutPreset? {
    if case let .preset(preset) = content {
      return preset
    }
    return nil
  }

  private static func authorizationMessage(for status: WorkoutAuthorizationStatus) -> String {
    switch status.state {
    case .notDetermined:
      return "Grant access on your paired iPhone to track pace, distance, and heart rate."
    case .denied:
      return "Enable Health permissions in iPhone Settings to track workouts."
    case .limited:
      return "Grant full access on iPhone for complete workout analytics."
    case .authorized:
      if status.hasOptionalLimitations {
        return "Optional metrics are disabled. Enable them on iPhone for richer stats."
      }
      return "Health permissions are active."
    }
  }

  private static func summary(for session: WorkoutSession) -> String {
    var components: [String] = []
    if let duration = session.totalDuration ?? session.summary.duration {
      components.append(self.formatDuration(duration))
    }
    if let distance = session.summary.totalDistance {
      components.append(self.formatKilometres(distance))
    }
    return components.joined(separator: " • ")
  }

  private static func presetSummary(_ preset: WorkoutPreset) -> String {
    var values: [String] = []
    let duration = preset.totalPlannedDuration
    if duration > 0 {
      values.append(self.formatDuration(duration))
    }
    let distance = preset.totalPlannedDistance
    if distance > 0 {
      values.append(self.formatKilometres(distance))
    }
    return values.joined(separator: " • ")
  }

  private static func quickStartSubtitle(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun, .indoorRun:
      "Auto-pause + splits"
    case .outdoorWalk:
      "Distance & pace logging"
    case .indoorCycle:
      "Cadence ready"
    case .strength:
      "Supersets tracking"
    case .mobility:
      "Guided intervals"
    case .refereeDrill:
      "Match sprint repeats"
    case .custom:
      "Build your own"
    }
  }

  private static func icon(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun, .indoorRun:
      "figure.run"
    case .outdoorWalk:
      "figure.walk"
    case .indoorCycle:
      "bicycle"
    case .strength:
      "dumbbell"
    case .mobility:
      "figure.cooldown"
    case .refereeDrill:
      "whistle"
    case .custom:
      "star"
    }
  }

  static func formatDuration(_ time: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter.string(from: time) ?? "0m"
  }

  static func formatKilometres(_ meters: Double) -> String {
    let kilometres = meters / 1000
    return String(format: "%.1f km", kilometres)
  }
}

@MainActor
final class WorkoutModeViewModel: ObservableObject {
  @Published private(set) var authorization: WorkoutAuthorizationStatus = .init(state: .notDetermined)
  @Published private(set) var presets: [WorkoutPreset] = []
  @Published private(set) var activeSession: WorkoutSession?
  @Published private(set) var lastCompletedSession: WorkoutSession?
  @Published private(set) var isActiveSessionPaused = false
  @Published private(set) var lapCount = 0
  @Published private(set) var isRecordingSegment = false
  @Published private(set) var liveMetrics: WorkoutLiveMetrics?
  @Published var errorMessage: String?
  @Published var isPerformingAction = false
  @Published var recoveryAction: String?
  @Published private(set) var selectionItems: [WorkoutSelectionItem] = []
  @Published var focusedSelectionID: WorkoutSelectionItem.ID?
  @Published private(set) var presentationState: WorkoutPresentationState = .list
  @Published private(set) var dwellState: WorkoutSelectionDwellState = .idle

  var selectionDwellConfiguration: WorkoutSelectionDwellConfiguration {
    self.dwellConfiguration
  }

  private let services: WorkoutServices
  private unowned let appModeController: AppModeController
  private var metricsTask: Task<Void, Never>?
  private var dwellTask: Task<Void, Never>?
  private var lastObservedVelocity: Double = 0
  private var lastCommittedSelectionID: WorkoutSelectionItem.ID?
  private let dwellConfiguration: WorkoutSelectionDwellConfiguration
  private let quickStartKinds: [WorkoutKind] = [.outdoorRun, .outdoorWalk, .strength, .mobility]

  init(
    services: WorkoutServices,
    appModeController: AppModeController,
    dwellConfiguration: WorkoutSelectionDwellConfiguration = .standard)
  {
    self.services = services
    self.appModeController = appModeController
    self.dwellConfiguration = dwellConfiguration
    self.rebuildSelectionItems()
  }

  deinit {
    metricsTask?.cancel()
    dwellTask?.cancel()
  }

  /// Clears all active session state to ensure UI consistency
  private func clearActiveSessionState() {
    self.activeSession = nil
    self.isActiveSessionPaused = false
    self.lapCount = 0
    self.isRecordingSegment = false
    self.liveMetrics = nil
    self.metricsTask?.cancel()
    self.metricsTask = nil
    self.presentationState = .list
    if let lastCommittedSelectionID,
       selectionItems.contains(where: { $0.id == lastCommittedSelectionID })
    {
      self.focusedSelectionID = lastCommittedSelectionID
    }
  }

  private func beginConsumingLiveMetrics(for sessionId: UUID) {
    self.metricsTask?.cancel()
    let stream = self.services.sessionTracker.liveMetricsStream()
    self.metricsTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await metrics in stream {
        guard metrics.sessionId == sessionId else { continue }
        self.liveMetrics = metrics
        if let active = self.activeSession, active.id == sessionId {
          self.activeSession = self.sessionUpdating(active, with: metrics)
        }
      }
    }
  }

  private func sessionUpdating(_ session: WorkoutSession, with metrics: WorkoutLiveMetrics) -> WorkoutSession {
    var updated = session
    if let elapsed = metrics.elapsedTime {
      updated.summary.duration = elapsed
    }
    if let distance = metrics.totalDistance {
      updated.summary.totalDistance = distance
    }
    if let energy = metrics.activeEnergy {
      updated.summary.activeEnergy = energy
    }
    if let heart = metrics.heartRate {
      updated.summary.averageHeartRate = heart
    }
    return updated
  }

  private func rebuildSelectionItems() {
    var items: [WorkoutSelectionItem] = []

    if self.shouldShowAuthorizationItem {
      let diagnostics = Array(authorization.deniedOptionalMetrics)
      items.append(
        WorkoutSelectionItem(
          id: .authorization,
          content: .authorization(status: self.authorization, diagnostics: diagnostics)))
    }

    if let lastCompletedSession {
      items.append(
        WorkoutSelectionItem(
          id: .lastCompleted(lastCompletedSession.id),
          content: .lastCompleted(session: lastCompletedSession)))
    }

    for kind in self.quickStartKinds where kind != .custom {
      items.append(
        WorkoutSelectionItem(
          id: .quickStart(kind),
          content: .quickStart(kind: kind)))
    }

    if self.presets.isEmpty {
      items.append(WorkoutSelectionItem(id: .emptyPresets, content: .emptyPresets))
    } else {
      for preset in self.presets {
        items.append(
          WorkoutSelectionItem(
            id: .preset(preset.id),
            content: .preset(preset: preset)))
      }
    }

    self.selectionItems = items

    if let currentFocus = focusedSelectionID, !items.contains(where: { $0.id == currentFocus }) {
      self.focusedSelectionID = nil
    }

    switch self.presentationState {
    case let .preview(item), let .starting(item):
      if !items.contains(item) {
        self.presentationState = .list
      }
    default:
      break
    }

    if self.presentationState == .list, self.focusedSelectionID == nil, let lastCommittedSelectionID {
      if items.contains(where: { $0.id == lastCommittedSelectionID }) {
        self.focusedSelectionID = lastCommittedSelectionID
      }
    }
  }

  private var shouldShowAuthorizationItem: Bool {
    !self.authorization.isAuthorized || self.authorization.hasOptionalLimitations
  }

  private func selectionItem(for preset: WorkoutPreset) -> WorkoutSelectionItem {
    if let existing = selectionItems.first(where: { $0.preset?.id == preset.id }) {
      return existing
    }
    return WorkoutSelectionItem(id: .preset(preset.id), content: .preset(preset: preset))
  }

  private func selectionItem(for kind: WorkoutKind) -> WorkoutSelectionItem {
    if let existing = selectionItems.first(where: { $0.quickStartKind == kind }) {
      return existing
    }
    return WorkoutSelectionItem(id: .quickStart(kind), content: .quickStart(kind: kind))
  }

  func updateFocusedSelection(to itemID: WorkoutSelectionItem.ID?, crownVelocity: Double) {
    self.lastObservedVelocity = crownVelocity

    guard self.presentationState == .list else {
      self.cancelPendingDwell()
      self.focusedSelectionID = itemID
      return
    }

    if self.focusedSelectionID != itemID {
      self.focusedSelectionID = itemID
      self.cancelPendingDwell()
      guard let itemID else { return }
      self.startDwellIfEligible(for: itemID, velocity: crownVelocity)
    } else {
      guard let itemID else {
        self.cancelPendingDwell()
        return
      }

      if abs(crownVelocity) > self.dwellConfiguration.velocityThreshold {
        self.cancelPendingDwell()
      } else if case .idle = self.dwellState {
        self.startDwellIfEligible(for: itemID, velocity: crownVelocity)
      }
    }
  }

  func cancelDwellDueToMotion() {
    self.cancelPendingDwell()
  }

  private func startDwellIfEligible(for itemID: WorkoutSelectionItem.ID, velocity: Double) {
    guard abs(velocity) <= self.dwellConfiguration.velocityThreshold else { return }
    guard let item = selectionItems.first(where: { $0.id == itemID }), item.allowsDwell else { return }

    self.dwellTask?.cancel()
    let startDate = Date()
    self.dwellState = .pending(itemID: itemID, startedAt: startDate)

    let dwellDuration = self.dwellConfiguration.dwellDuration
    self.dwellTask = Task { [weak self] in
      guard dwellDuration > 0 else { return }
      let delay = UInt64(dwellDuration * 1_000_000_000)
      try? await Task.sleep(nanoseconds: delay)
      await MainActor.run {
        self?.completeDwell(for: itemID, expectedStartDate: startDate)
      }
    }
  }

  private func completeDwell(for itemID: WorkoutSelectionItem.ID, expectedStartDate: Date) {
    guard case let .pending(pendingID, startedAt) = dwellState, pendingID == itemID,
          startedAt == expectedStartDate
    else {
      return
    }

    self.dwellTask = nil

    guard self.focusedSelectionID == itemID else {
      self.dwellState = .idle
      return
    }

    guard abs(self.lastObservedVelocity) <= self.dwellConfiguration.velocityThreshold else {
      self.dwellState = .idle
      return
    }

    guard let item = selectionItems.first(where: { $0.id == itemID }), item.allowsDwell else {
      self.dwellState = .idle
      return
    }

    guard self.presentationState == .list else {
      self.dwellState = .idle
      return
    }

    self.dwellState = .locked(itemID: itemID, completedAt: Date())
    self.lastCommittedSelectionID = itemID
    self.presentationState = .preview(item)
  }

  private func cancelPendingDwell() {
    self.dwellTask?.cancel()
    self.dwellTask = nil
    self.dwellState = .idle
  }

  func requestPreview(for item: WorkoutSelectionItem) {
    guard item.allowsDwell else { return }
    self.cancelPendingDwell()
    self.lastCommittedSelectionID = item.id
    self.focusedSelectionID = item.id
    self.presentationState = .preview(item)
  }

  func returnToList() {
    self.cancelPendingDwell()
    self.presentationState = .list
    if let lastCommittedSelectionID,
       selectionItems.contains(where: { $0.id == lastCommittedSelectionID })
    {
      self.focusedSelectionID = lastCommittedSelectionID
    } else {
      self.focusedSelectionID = self.selectionItems.first?.id
    }
    self.errorMessage = nil
    self.recoveryAction = nil
  }

  func startSelection(for item: WorkoutSelectionItem) {
    switch item.content {
    case let .quickStart(kind):
      self.quickStart(kind: kind)
    case let .preset(preset):
      self.startPreset(preset)
    case let .lastCompleted(session):
      let selectionItem = self.selectionItems.first(where: { $0.id == item.id }) ?? item
      if let presetID = session.presetId,
         let preset = presets.first(where: { $0.id == presetID })
      {
        let configuration = WorkoutSessionConfiguration(
          kind: preset.kind,
          presetId: preset.id,
          title: preset.title,
          segments: preset.segments,
          metadata: ["source": "repeat_preset"])
        self.beginStartingSession(selectionItem: selectionItem, configuration: configuration)
      } else {
        var metadata = ["source": "repeat_last"]
        if let priorSource = session.metadata["source"] {
          metadata["previousSource"] = priorSource
        }
        let configuration = WorkoutSessionConfiguration(
          kind: session.kind,
          title: session.title,
          segments: session.segments,
          metadata: metadata)
        self.beginStartingSession(selectionItem: selectionItem, configuration: configuration)
      }
    case .authorization, .emptyPresets:
      break
    }
  }

  private func beginStartingSession(selectionItem: WorkoutSelectionItem, configuration: WorkoutSessionConfiguration) {
    Task { @MainActor in
      self.cancelPendingDwell()

      guard self.authorization.isAuthorized else {
        let error = WorkoutError.authorizationDenied
        self.presentationState = .error(selectionItem, error)
        self.errorMessage = error.errorDescription
        self.recoveryAction = error.recoveryAction
        self.isPerformingAction = false
        return
      }

      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      self.presentationState = .starting(selectionItem)
      self.lastCommittedSelectionID = selectionItem.id
      do {
        let session = try await self.services.sessionTracker.startSession(configuration: configuration)
        self.activeSession = session
        self.isActiveSessionPaused = false
        self.lapCount = 0
        self.isRecordingSegment = false
        self.beginConsumingLiveMetrics(for: session.id)
        self.appModeController.select(.workout)
        self.errorMessage = nil
        self.recoveryAction = nil
        self.presentationState = .session(session)
      } catch let sessionError as WorkoutSessionError {
        let workoutError = self.mapStartError(sessionError)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
        self.presentationState = .error(selectionItem, workoutError)
      } catch {
        let workoutError = WorkoutError.sessionStartFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
        self.presentationState = .error(selectionItem, workoutError)
      }
    }
  }

  private func mapStartError(_ sessionError: WorkoutSessionError) -> WorkoutError {
    switch sessionError {
    case .healthDataUnavailable:
      .healthDataUnavailable
    case .sessionNotFound:
      .sessionNotFound
    case .collectionBeginFailed,
         .collectionEndFailed:
      .collectionFailed(reason: sessionError.localizedDescription)
    case .finishFailed:
      .sessionFinishFailed(reason: sessionError.localizedDescription)
    }
  }

  func bootstrap() async {
    await self.refreshAuthorization()
    await self.loadPresets()
    await self.loadHistory()
  }

  func refreshAuthorization() async {
    self.authorization = await self.services.authorizationManager.authorizationStatus()
    self.rebuildSelectionItems()
  }

  func requestAuthorization() {
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        let status = try await self.services.authorizationManager.requestAuthorization()
        self.authorization = status
        self.rebuildSelectionItems()
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let authError as WorkoutAuthorizationError {
        // Map specific authorization errors to appropriate user-facing messages
        let workoutError: WorkoutError = switch authError {
        case .healthDataUnavailable:
          .healthDataUnavailable
        case .requestFailed:
          .authorizationRequestFailed
        }
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        // Fallback for any other authorization-related errors
        let workoutError = WorkoutError.authorizationDenied
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func startPreset(_ preset: WorkoutPreset) {
    let selectionItem = selectionItem(for: preset)
    let configuration = WorkoutSessionConfiguration(
      kind: preset.kind,
      presetId: preset.id,
      title: preset.title,
      segments: preset.segments,
      metadata: ["source": "preset"])
    self.beginStartingSession(selectionItem: selectionItem, configuration: configuration)
  }

  func quickStart(kind: WorkoutKind) {
    let selectionItem = selectionItem(for: kind)
    let configuration = WorkoutSessionConfiguration(
      kind: kind,
      title: kind.displayName,
      metadata: ["source": "quick_start"])
    self.beginStartingSession(selectionItem: selectionItem, configuration: configuration)
  }

  func endActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }

      do {
        // End the HealthKit session first
        let finished = try await self.services.sessionTracker.endSession(id: sessionID, at: Date())
        self.metricsTask?.cancel()
        self.metricsTask = nil
        self.liveMetrics = nil

        // Try to save to history - if this fails, we still want to clear the UI state
        do {
          try await self.services.historyStore.saveSession(finished)
          self.lastCompletedSession = finished
          self.clearActiveSessionState()
          self.rebuildSelectionItems()
          self.errorMessage = nil
          self.recoveryAction = nil
        } catch let historyError {
          // History save failed but session ended successfully - clear UI state
          self.clearActiveSessionState()
          self.lastCompletedSession = nil // Don't show incomplete session
          self.rebuildSelectionItems()
          let workoutError = WorkoutError.historyPersistenceFailed(reason: historyError.localizedDescription)
          self.errorMessage = workoutError.errorDescription
          self.recoveryAction = workoutError.recoveryAction
        }
      } catch let sessionError as WorkoutSessionError {
        // Session ending failed entirely
        let workoutError: WorkoutError = switch sessionError {
        case .healthDataUnavailable:
          .healthDataUnavailable
        case .sessionNotFound:
          .sessionNotFound
        case .collectionBeginFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .collectionEndFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .finishFailed:
          .sessionFinishFailed(reason: sessionError.localizedDescription)
        }
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch let sessionError {
        // Session ending failed entirely
        let workoutError = WorkoutError.sessionEndFailed(reason: sessionError.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  /// Ends the active session without persisting it so the user can immediately start a new workout type.
  func abandonActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        _ = try await self.services.sessionTracker.endSession(id: sessionID, at: Date())
        self.activeSession = nil
        self.isActiveSessionPaused = false
        self.lapCount = 0
        self.isRecordingSegment = false
        self.liveMetrics = nil
        self.metricsTask?.cancel()
        self.metricsTask = nil
        self.errorMessage = nil
        self.recoveryAction = nil
        self.presentationState = .list
        if let lastCommittedSelectionID,
           self.selectionItems.contains(where: { $0.id == lastCommittedSelectionID })
        {
          self.focusedSelectionID = lastCommittedSelectionID
        }
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = switch sessionError {
        case .healthDataUnavailable:
          .healthDataUnavailable
        case .sessionNotFound:
          .sessionNotFound
        case .collectionBeginFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .collectionEndFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .finishFailed:
          .sessionFinishFailed(reason: sessionError.localizedDescription)
        }
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionEndFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func markSegment() {
    guard let sessionID = activeSession?.id else { return }
    guard !self.isRecordingSegment else { return }

    self.isRecordingSegment = true

    Task { @MainActor in
      defer { self.isRecordingSegment = false }

      let nextIndex = self.lapCount + 1
      await self.services.sessionTracker.recordEvent(
        .lap(index: nextIndex, timestamp: Date()),
        sessionId: sessionID)
      self.lapCount = nextIndex
      self.errorMessage = nil
    }
  }

  func reloadPresets() {
    Task { @MainActor in
      await self.loadPresets()
    }
  }

  func reloadContent() {
    Task { @MainActor in
      await self.loadPresets()
      await self.loadHistory()
    }
  }

  func pauseActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        try await self.services.sessionTracker.pauseSession(id: sessionID)
        self.isActiveSessionPaused = true
        self.metricsTask?.cancel()
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = switch sessionError {
        case .healthDataUnavailable:
          .healthDataUnavailable
        case .sessionNotFound:
          .sessionNotFound
        case .collectionBeginFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .collectionEndFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .finishFailed:
          .sessionFinishFailed(reason: sessionError.localizedDescription)
        }
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionEndFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  func resumeActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }
      do {
        try await self.services.sessionTracker.resumeSession(id: sessionID)
        self.isActiveSessionPaused = false
        self.beginConsumingLiveMetrics(for: sessionID)
        self.errorMessage = nil
        self.recoveryAction = nil
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = switch sessionError {
        case .healthDataUnavailable:
          .healthDataUnavailable
        case .sessionNotFound:
          .sessionNotFound
        case .collectionBeginFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .collectionEndFailed:
          .collectionFailed(reason: sessionError.localizedDescription)
        case .finishFailed:
          .sessionFinishFailed(reason: sessionError.localizedDescription)
        }
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      } catch {
        let workoutError = WorkoutError.sessionStartFailed(reason: error.localizedDescription)
        self.errorMessage = workoutError.errorDescription
        self.recoveryAction = workoutError.recoveryAction
      }
    }
  }

  private func loadPresets() async {
    do {
      self.presets = try await self.services.presetStore.loadPresets()
      if self.presets.isEmpty {
        self.presets = [WorkoutModeBootstrap.samplePreset]
        try await self.services.presetStore.savePreset(WorkoutModeBootstrap.samplePreset)
      }
      self.rebuildSelectionItems()
    } catch {
      let workoutError = WorkoutError.presetLoadFailed(reason: error.localizedDescription)
      self.errorMessage = workoutError.errorDescription
      self.recoveryAction = workoutError.recoveryAction
    }
  }

  private func loadHistory() async {
    do {
      let sessions = try await services.historyStore.loadSessions(limit: 1)
      self.lastCompletedSession = sessions.first
      self.rebuildSelectionItems()
    } catch {
      let workoutError = WorkoutError.historyPersistenceFailed(reason: error.localizedDescription)
      self.errorMessage = workoutError.errorDescription
      self.recoveryAction = workoutError.recoveryAction
    }
  }
}
