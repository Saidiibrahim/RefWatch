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
            return "HealthKit access denied. Manage workout permissions on your paired iPhone."
        case .healthDataUnavailable:
            return "HealthKit is not available on this device."
        case .authorizationRequestFailed:
            return "Failed to request HealthKit authorization. Please try again."
        case .sessionNotFound:
            return "Workout session not found. Please try starting a new workout."
        case .sessionStartFailed(let reason):
            return "Failed to start workout: \(reason)"
        case .sessionEndFailed(let reason):
            return "Failed to end workout: \(reason)"
        case .collectionFailed(let reason):
            return "Failed to collect workout data: \(reason)"
        case .sessionFinishFailed(let reason):
            return "Failed to finish saving workout data: \(reason)"
        case .historyPersistenceFailed(let reason):
            return "Workout ended but couldn't save to history: \(reason)"
        case .presetLoadFailed(let reason):
            return "Failed to load workout presets: \(reason)"
        }
    }

    var recoveryAction: String? {
        switch self {
        case .authorizationDenied:
            return "On your iPhone, open Settings > Health > Data Access & Devices > RefWatch to enable workout permissions."
        case .healthDataUnavailable:
            return "HealthKit is not supported on this device. Workout features may be limited."
        case .authorizationRequestFailed:
            return "Try requesting permissions again or restart the app."
        case .sessionNotFound:
            return "Start a new workout session."
        case .sessionStartFailed:
            return "Try starting the workout again or restart the app."
        case .sessionEndFailed:
            return "The workout ended but may not have been saved properly."
        case .collectionFailed:
            return "Try ending the workout again or restart the app."
        case .sessionFinishFailed:
            return "Your workout data may be incomplete. Try syncing later."
        case .historyPersistenceFailed:
            return "Your workout data was recorded but couldn't be saved. Try syncing later."
        case .presetLoadFailed:
            return "Using default presets. Check your connection and try again."
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
    switch content {
    case .authorization, .emptyPresets:
      return .informational
    case .lastCompleted, .quickStart, .preset:
      return .preview
    }
  }

  var allowsDwell: Bool {
    interaction == .preview
  }

  var title: String {
    switch content {
    case .authorization(let status, _):
      switch status.state {
      case .notDetermined:
        return "Grant on iPhone"
      case .denied:
        return "Access Denied on iPhone"
      case .limited:
        return "Limited Access on iPhone"
      case .authorized:
        return "Manage on iPhone"
      }
    case .lastCompleted(let session):
      return session.title
    case .quickStart(let kind):
      return kind.displayName
    case .preset(let preset):
      return preset.title
    case .emptyPresets:
      return "Sync Workouts"
    }
  }

  var subtitle: String? {
    switch content {
    case .authorization(let status, _):
      return WorkoutSelectionItem.authorizationMessage(for: status)
    case .lastCompleted(let session):
      return WorkoutSelectionItem.summary(for: session)
    case .quickStart(let kind):
      return WorkoutSelectionItem.quickStartSubtitle(for: kind)
    case .preset(let preset):
      return WorkoutSelectionItem.presetSummary(preset)
    case .emptyPresets:
      return "Create workouts on iPhone"
    }
  }

  var iconSystemName: String? {
    switch content {
    case .authorization:
      return "heart.text.square"
    case .lastCompleted(let session):
      return WorkoutSelectionItem.icon(for: session.kind)
    case .quickStart(let kind):
      return WorkoutSelectionItem.icon(for: kind)
    case .preset(let preset):
      return WorkoutSelectionItem.icon(for: preset.kind)
    case .emptyPresets:
      return "iphone"
    }
  }

  var diagnosticsDescription: String? {
    switch content {
    case .authorization(_, let diagnostics):
      return WorkoutSelectionItem.authorizationDiagnosticsSummary(for: diagnostics)
    default:
      return nil
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
    if case .authorization(let status, _) = content {
      return status
    }
    return nil
  }

  var lastCompletedSession: WorkoutSession? {
    if case .lastCompleted(let session) = content {
      return session
    }
    return nil
  }

  var quickStartKind: WorkoutKind? {
    if case .quickStart(let kind) = content {
      return kind
    }
    return nil
  }

  var preset: WorkoutPreset? {
    if case .preset(let preset) = content {
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
      components.append(formatDuration(duration))
    }
    if let distance = session.summary.totalDistance {
      components.append(formatKilometres(distance))
    }
    return components.joined(separator: " • ")
  }

  private static func presetSummary(_ preset: WorkoutPreset) -> String {
    var values: [String] = []
    let duration = preset.totalPlannedDuration
    if duration > 0 {
      values.append(formatDuration(duration))
    }
    let distance = preset.totalPlannedDistance
    if distance > 0 {
      values.append(formatKilometres(distance))
    }
    return values.joined(separator: " • ")
  }

  private static func quickStartSubtitle(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun, .indoorRun:
      return "Auto-pause + splits"
    case .outdoorWalk:
      return "Distance & pace logging"
    case .indoorCycle:
      return "Cadence ready"
    case .strength:
      return "Supersets tracking"
    case .mobility:
      return "Guided intervals"
    case .refereeDrill:
      return "Match sprint repeats"
    case .custom:
      return "Build your own"
    }
  }

  private static func icon(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun, .indoorRun:
      return "figure.run"
    case .outdoorWalk:
      return "figure.walk"
    case .indoorCycle:
      return "bicycle"
    case .strength:
      return "dumbbell"
    case .mobility:
      return "figure.cooldown"
    case .refereeDrill:
      return "whistle"
    case .custom:
      return "star"
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
  @Published private(set) var authorization: WorkoutAuthorizationStatus = WorkoutAuthorizationStatus(state: .notDetermined)
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
    dwellConfiguration
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
    dwellConfiguration: WorkoutSelectionDwellConfiguration = .standard
  ) {
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
    metricsTask?.cancel()
    metricsTask = nil
    presentationState = .list
    if let lastCommittedSelectionID,
       selectionItems.contains(where: { $0.id == lastCommittedSelectionID }) {
      focusedSelectionID = lastCommittedSelectionID
    }
  }

  private func beginConsumingLiveMetrics(for sessionId: UUID) {
    metricsTask?.cancel()
    let stream = services.sessionTracker.liveMetricsStream()
    metricsTask = Task { @MainActor [weak self] in
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

    if shouldShowAuthorizationItem {
      let diagnostics = Array(authorization.deniedOptionalMetrics)
      items.append(
        WorkoutSelectionItem(
          id: .authorization,
          content: .authorization(status: authorization, diagnostics: diagnostics)
        )
      )
    }

    if let lastCompletedSession {
      items.append(
        WorkoutSelectionItem(
          id: .lastCompleted(lastCompletedSession.id),
          content: .lastCompleted(session: lastCompletedSession)
        )
      )
    }

    for kind in quickStartKinds where kind != .custom {
      items.append(
        WorkoutSelectionItem(
          id: .quickStart(kind),
          content: .quickStart(kind: kind)
        )
      )
    }

    if presets.isEmpty {
      items.append(WorkoutSelectionItem(id: .emptyPresets, content: .emptyPresets))
    } else {
      for preset in presets {
        items.append(
          WorkoutSelectionItem(
            id: .preset(preset.id),
            content: .preset(preset: preset)
          )
        )
      }
    }

    selectionItems = items

    if let currentFocus = focusedSelectionID, !items.contains(where: { $0.id == currentFocus }) {
      focusedSelectionID = nil
    }

    switch presentationState {
    case .preview(let item), .starting(let item):
      if !items.contains(item) {
        presentationState = .list
      }
    default:
      break
    }

    if presentationState == .list, focusedSelectionID == nil, let lastCommittedSelectionID {
      if items.contains(where: { $0.id == lastCommittedSelectionID }) {
        focusedSelectionID = lastCommittedSelectionID
      }
    }
  }

  private var shouldShowAuthorizationItem: Bool {
    !authorization.isAuthorized || authorization.hasOptionalLimitations
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
    lastObservedVelocity = crownVelocity

    guard presentationState == .list else {
      cancelPendingDwell()
      focusedSelectionID = itemID
      return
    }

    if focusedSelectionID != itemID {
      focusedSelectionID = itemID
      cancelPendingDwell()
      guard let itemID else { return }
      startDwellIfEligible(for: itemID, velocity: crownVelocity)
    } else {
      guard let itemID else {
        cancelPendingDwell()
        return
      }

      if abs(crownVelocity) > dwellConfiguration.velocityThreshold {
        cancelPendingDwell()
      } else if case .idle = dwellState {
        startDwellIfEligible(for: itemID, velocity: crownVelocity)
      }
    }
  }

  func cancelDwellDueToMotion() {
    cancelPendingDwell()
  }

  private func startDwellIfEligible(for itemID: WorkoutSelectionItem.ID, velocity: Double) {
    guard abs(velocity) <= dwellConfiguration.velocityThreshold else { return }
    guard let item = selectionItems.first(where: { $0.id == itemID }), item.allowsDwell else { return }

    dwellTask?.cancel()
    let startDate = Date()
    dwellState = .pending(itemID: itemID, startedAt: startDate)

    let dwellDuration = dwellConfiguration.dwellDuration
    dwellTask = Task { [weak self] in
      guard dwellDuration > 0 else { return }
      let delay = UInt64(dwellDuration * 1_000_000_000)
      try? await Task.sleep(nanoseconds: delay)
      await MainActor.run {
        self?.completeDwell(for: itemID, expectedStartDate: startDate)
      }
    }
  }

  private func completeDwell(for itemID: WorkoutSelectionItem.ID, expectedStartDate: Date) {
    guard case .pending(let pendingID, let startedAt) = dwellState, pendingID == itemID, startedAt == expectedStartDate else {
      return
    }

    dwellTask = nil

    guard focusedSelectionID == itemID else {
      dwellState = .idle
      return
    }

    guard abs(lastObservedVelocity) <= dwellConfiguration.velocityThreshold else {
      dwellState = .idle
      return
    }

    guard let item = selectionItems.first(where: { $0.id == itemID }), item.allowsDwell else {
      dwellState = .idle
      return
    }

    guard presentationState == .list else {
      dwellState = .idle
      return
    }

    dwellState = .locked(itemID: itemID, completedAt: Date())
    lastCommittedSelectionID = itemID
    presentationState = .preview(item)
  }

  private func cancelPendingDwell() {
    dwellTask?.cancel()
    dwellTask = nil
    dwellState = .idle
  }

  func requestPreview(for item: WorkoutSelectionItem) {
    guard item.allowsDwell else { return }
    cancelPendingDwell()
    lastCommittedSelectionID = item.id
    focusedSelectionID = item.id
    presentationState = .preview(item)
  }

  func returnToList() {
    cancelPendingDwell()
    presentationState = .list
    if let lastCommittedSelectionID,
       selectionItems.contains(where: { $0.id == lastCommittedSelectionID }) {
      focusedSelectionID = lastCommittedSelectionID
    } else {
      focusedSelectionID = selectionItems.first?.id
    }
    errorMessage = nil
    recoveryAction = nil
  }

  func startSelection(for item: WorkoutSelectionItem) {
    switch item.content {
    case .quickStart(let kind):
      quickStart(kind: kind)
    case .preset(let preset):
      startPreset(preset)
    case .lastCompleted(let session):
      let selectionItem = selectionItems.first(where: { $0.id == item.id }) ?? item
      if let presetID = session.presetId,
         let preset = presets.first(where: { $0.id == presetID }) {
        let configuration = WorkoutSessionConfiguration(
          kind: preset.kind,
          presetId: preset.id,
          title: preset.title,
          segments: preset.segments,
          metadata: ["source": "repeat_preset"]
        )
        beginStartingSession(selectionItem: selectionItem, configuration: configuration)
      } else {
        var metadata: [String: String] = ["source": "repeat_last"]
        if let priorSource = session.metadata["source"] {
          metadata["previousSource"] = priorSource
        }
        let configuration = WorkoutSessionConfiguration(
          kind: session.kind,
          title: session.title,
          segments: session.segments,
          metadata: metadata
        )
        beginStartingSession(selectionItem: selectionItem, configuration: configuration)
      }
    case .authorization, .emptyPresets:
      break
    }
  }

  private func beginStartingSession(selectionItem: WorkoutSelectionItem, configuration: WorkoutSessionConfiguration) {
    Task { @MainActor in
      self.cancelPendingDwell()

      guard authorization.isAuthorized else {
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
      return .healthDataUnavailable
    case .sessionNotFound:
      return .sessionNotFound
    case .collectionBeginFailed,
         .collectionEndFailed:
      return .collectionFailed(reason: sessionError.localizedDescription)
    case .finishFailed:
      return .sessionFinishFailed(reason: sessionError.localizedDescription)
    }
  }

  func bootstrap() async {
    await refreshAuthorization()
    await loadPresets()
    await loadHistory()
  }

  func refreshAuthorization() async {
    authorization = await services.authorizationManager.authorizationStatus()
    rebuildSelectionItems()
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
        let workoutError: WorkoutError = {
          switch authError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .requestFailed:
            return .authorizationRequestFailed
          }
        }()
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
      metadata: ["source": "preset"]
    )
    beginStartingSession(selectionItem: selectionItem, configuration: configuration)
  }

  func quickStart(kind: WorkoutKind) {
    let selectionItem = selectionItem(for: kind)
    let configuration = WorkoutSessionConfiguration(
      kind: kind,
      title: kind.displayName,
      metadata: ["source": "quick_start"]
    )
    beginStartingSession(selectionItem: selectionItem, configuration: configuration)
  }

  func endActiveSession() {
    guard let sessionID = activeSession?.id else { return }
    Task { @MainActor in
      self.isPerformingAction = true
      defer { self.isPerformingAction = false }

      do {
        // End the HealthKit session first
        let finished = try await self.services.sessionTracker.endSession(id: sessionID, at: Date())
        metricsTask?.cancel()
        metricsTask = nil
        liveMetrics = nil

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
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
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
           self.selectionItems.contains(where: { $0.id == lastCommittedSelectionID }) {
          self.focusedSelectionID = lastCommittedSelectionID
        }
      } catch let sessionError as WorkoutSessionError {
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
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
    guard !isRecordingSegment else { return }

    isRecordingSegment = true

    Task { @MainActor in
      defer { self.isRecordingSegment = false }

      let nextIndex = self.lapCount + 1
      await self.services.sessionTracker.recordEvent(
        .lap(index: nextIndex, timestamp: Date()),
        sessionId: sessionID
      )
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
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
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
        let workoutError: WorkoutError = {
          switch sessionError {
          case .healthDataUnavailable:
            return .healthDataUnavailable
          case .sessionNotFound:
            return .sessionNotFound
          case .collectionBeginFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .collectionEndFailed:
            return .collectionFailed(reason: sessionError.localizedDescription)
          case .finishFailed:
            return .sessionFinishFailed(reason: sessionError.localizedDescription)
          }
        }()
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
      presets = try await services.presetStore.loadPresets()
      if presets.isEmpty {
        presets = [WorkoutModeBootstrap.samplePreset]
        try await services.presetStore.savePreset(WorkoutModeBootstrap.samplePreset)
      }
      rebuildSelectionItems()
    } catch {
      let workoutError = WorkoutError.presetLoadFailed(reason: error.localizedDescription)
      errorMessage = workoutError.errorDescription
      recoveryAction = workoutError.recoveryAction
    }
  }

  private func loadHistory() async {
    do {
      let sessions = try await services.historyStore.loadSessions(limit: 1)
      lastCompletedSession = sessions.first
      rebuildSelectionItems()
    } catch {
      let workoutError = WorkoutError.historyPersistenceFailed(reason: error.localizedDescription)
      errorMessage = workoutError.errorDescription
      recoveryAction = workoutError.recoveryAction
    }
  }
}
