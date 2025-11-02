import XCTest
@testable import RefZone_Watch_App
import RefWorkoutCore

@MainActor
final class WorkoutModeViewModelTests: XCTestCase {
  func testBootstrapLoadsHistory() async throws {
    let session = WorkoutSession(
      state: .ended,
      kind: .outdoorRun,
      title: "Intervals",
      startedAt: Date().addingTimeInterval(-1800),
      endedAt: Date()
    )

    let services = WorkoutServices.inMemoryStub(historySessions: [session])
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()

    XCTAssertEqual(viewModel.lastCompletedSession?.id, session.id)
    XCTAssertFalse(viewModel.presets.isEmpty)
    XCTAssertFalse(viewModel.selectionItems.isEmpty)
  }

  func testSelectionItemsRespectOrdering() async throws {
    let session = WorkoutSession(
      state: .ended,
      kind: .outdoorRun,
      title: "Tempo",
      startedAt: Date().addingTimeInterval(-1200),
      endedAt: Date()
    )

    let status = WorkoutAuthorizationStatus(
      state: .limited,
      deniedMetrics: [.vo2Max]
    )

    let preset = WorkoutModeBootstrap.samplePreset
    let services = WorkoutServices.inMemoryStub(
      presets: [preset],
      historySessions: [session],
      authorizationStatus: status
    )

    let viewModel = makeViewModel(services: services)
    await viewModel.bootstrap()

    let ids = viewModel.selectionItems.map(\.id)
    XCTAssertEqual(
      ids,
      [
        .authorization,
        .lastCompleted(session.id),
        .quickStart(.outdoorRun),
        .quickStart(.outdoorWalk),
        .quickStart(.strength),
        .quickStart(.mobility),
        .preset(preset.id)
      ]
    )

    let authorizationItem = try XCTUnwrap(viewModel.selectionItems.first)
    XCTAssertEqual(authorizationItem.authorizationStatus?.state, .limited)
    XCTAssertNotNil(authorizationItem.diagnosticsDescription)
  }

  func testDwellTransitionsToPreviewWhenCrownStable() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let config = WorkoutSelectionDwellConfiguration(dwellDuration: 0.05, velocityThreshold: 0.2)
    let viewModel = makeViewModel(services: services, dwellConfiguration: config)

    await viewModel.bootstrap()

    let itemID: WorkoutSelectionItem.ID = .quickStart(.outdoorRun)
    viewModel.updateFocusedSelection(to: itemID, crownVelocity: 0.05)

    await waitFor {
      if case .preview(let item) = viewModel.presentationState {
        return item.id == itemID
      }
      return false
    }

    if case .preview(let item) = viewModel.presentationState {
      XCTAssertEqual(item.id, itemID)
    } else {
      XCTFail("Expected preview state after dwell completes")
    }
  }

  func testDwellCancelsWhenVelocityExceedsThreshold() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let config = WorkoutSelectionDwellConfiguration(dwellDuration: 0.05, velocityThreshold: 0.15)
    let viewModel = makeViewModel(services: services, dwellConfiguration: config)

    await viewModel.bootstrap()

    let itemID: WorkoutSelectionItem.ID = .quickStart(.outdoorRun)
    viewModel.updateFocusedSelection(to: itemID, crownVelocity: 0.05)
    viewModel.updateFocusedSelection(to: itemID, crownVelocity: 0.4)

    // Allow time for the original dwell task to be cancelled.
    try await Task.sleep(nanoseconds: 80_000_000)

    XCTAssertEqual(viewModel.presentationState, .list)
    XCTAssertEqual(viewModel.dwellState, .idle)
  }

  func testRequestPreviewTransitionsPresentationState() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { $0.quickStartKind == .outdoorRun }))

    viewModel.requestPreview(for: item)

    if case .preview(let previewItem) = viewModel.presentationState {
      XCTAssertEqual(previewItem, item)
      XCTAssertEqual(viewModel.focusedSelectionID, item.id)
    } else {
      XCTFail("Expected preview presentation state after tapping item")
    }
  }

  func testReturnToListRestoresFocus() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { $0.quickStartKind == .outdoorRun }))

    viewModel.requestPreview(for: item)
    viewModel.returnToList()

    XCTAssertEqual(viewModel.presentationState, .list)
    XCTAssertEqual(viewModel.focusedSelectionID, item.id)
  }

  func testReturnToListClearsErrorAndRestoresFocus() async throws {
    var services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    services.sessionTracker = FailingSessionTracker()
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { $0.quickStartKind == .outdoorRun }))

    viewModel.requestPreview(for: item)
    viewModel.startSelection(for: item)

    await waitFor {
      if case .error = viewModel.presentationState { return true }
      return false
    }

    viewModel.returnToList()

    XCTAssertEqual(viewModel.presentationState, .list)
    XCTAssertEqual(viewModel.focusedSelectionID, item.id)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertNil(viewModel.recoveryAction)
  }

  func testStartSelectionFromLastCompletedRepeatsPreset() async throws {
    let preset = WorkoutModeBootstrap.samplePreset
    var session = WorkoutSession(
      state: .ended,
      kind: preset.kind,
      title: preset.title,
      startedAt: Date().addingTimeInterval(-1_800),
      endedAt: Date(),
      segments: preset.segments,
      summary: .init(totalDistance: 3_000, duration: 1_800),
      presetId: preset.id
    )
    session.metadata["source"] = "preset"

    let services = WorkoutServices.inMemoryStub(presets: [preset], historySessions: [session])
    let tracker = try XCTUnwrap(services.sessionTracker as? WorkoutSessionTrackerStub)
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()

    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { candidate in
      if case .lastCompleted = candidate.content { return true }
      return false
    }))

    viewModel.requestPreview(for: item)
    viewModel.startSelection(for: item)

    await waitFor {
      if case .session = viewModel.presentationState { return true }
      return false
    }

    if case .session(let active) = viewModel.presentationState {
      XCTAssertEqual(active.presetId, preset.id)
    } else {
      XCTFail("Expected active session presentation state")
    }

    let storedSessions = await tracker.sessions
    let metadata = try XCTUnwrap(storedSessions.values.first?.metadata)
    XCTAssertEqual(metadata["source"], "repeat_preset")
  }

  func testStartSelectionFailureEmitsErrorState() async throws {
    var services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    services.sessionTracker = FailingSessionTracker()
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { $0.quickStartKind == .outdoorRun }))

    viewModel.requestPreview(for: item)
    viewModel.startSelection(for: item)

    await waitFor {
      if case .error = viewModel.presentationState { return true }
      return false
    }

    if case .error(let failedItem, let error) = viewModel.presentationState {
      XCTAssertEqual(failedItem, item)
      XCTAssertEqual(error, .collectionFailed(reason: WorkoutSessionError.collectionBeginFailed.localizedDescription))
    } else {
      XCTFail("Expected error presentation state after failing to start session")
    }
  }

  func testRetryStartAfterErrorTransitionsToSession() async throws {
    let preset = WorkoutModeBootstrap.samplePreset
    let tracker = FlakySessionTracker(failuresBeforeSuccess: 1)
    var services = WorkoutServices.inMemoryStub(presets: [preset])
    services.sessionTracker = tracker
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { $0.quickStartKind == .outdoorRun }))

    viewModel.requestPreview(for: item)
    viewModel.startSelection(for: item)

    await waitFor {
      if case .error = viewModel.presentationState { return true }
      return false
    }

    viewModel.startSelection(for: item)

    await waitFor {
      if case .session = viewModel.presentationState { return true }
      return false
    }
  }

  func testStartSelectionFailureForPresetEmitsErrorState() async throws {
    let preset = WorkoutModeBootstrap.samplePreset
    var services = WorkoutServices.inMemoryStub(presets: [preset])
    services.sessionTracker = FailingSessionTracker()
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { candidate in
      if case .preset = candidate.content { return true }
      return false
    }))

    viewModel.requestPreview(for: item)
    viewModel.startSelection(for: item)

    await waitFor {
      if case .error = viewModel.presentationState { return true }
      return false
    }

    if case .error(let failedItem, let error) = viewModel.presentationState {
      XCTAssertEqual(failedItem, item)
      XCTAssertEqual(error, .collectionFailed(reason: WorkoutSessionError.collectionBeginFailed.localizedDescription))
    } else {
      XCTFail("Expected error presentation state for preset start failure")
    }
  }

  func testPauseAndResumeToggleState() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    viewModel.quickStart(kind: .outdoorRun)

    await waitFor { viewModel.activeSession != nil }
    if case .session = viewModel.presentationState {
      // expected
    } else {
      XCTFail("Expected session presentation state after quick start")
    }

    viewModel.pauseActiveSession()
    await waitFor { viewModel.isActiveSessionPaused }
    XCTAssertTrue(viewModel.isActiveSessionPaused)

    viewModel.resumeActiveSession()
    await waitFor { viewModel.isActiveSessionPaused == false }
    XCTAssertFalse(viewModel.isActiveSessionPaused)
  }

  func testMarkSegmentRecordsLap() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let tracker = services.sessionTracker as? WorkoutSessionTrackerStub
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    viewModel.quickStart(kind: .outdoorRun)

    await waitFor { viewModel.activeSession != nil }
    if case .session = viewModel.presentationState {
      // expected
    } else {
      XCTFail("Expected session presentation state after quick start")
    }
    XCTAssertEqual(viewModel.lapCount, 0)

    viewModel.markSegment()

    await waitFor { viewModel.lapCount == 1 }
    XCTAssertEqual(viewModel.lapCount, 1)
    XCTAssertFalse(viewModel.isRecordingSegment)

    if let tracker {
      let sessionID = try XCTUnwrap(viewModel.activeSession?.id)
      let storedEvents = await tracker.events
      let laps = storedEvents[sessionID] ?? []
      XCTAssertEqual(laps.count, 1)
      if let first = laps.first {
        if case let .lap(index, _) = first {
          XCTAssertEqual(index, 1)
        } else {
          XCTFail("Expected lap event")
        }
      } else {
        XCTFail("Expected lap event")
      }
    } else {
      XCTFail("Expected WorkoutSessionTrackerStub")
    }
  }

  func testMarkSegmentIgnoresRapidDoubleTap() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let tracker = services.sessionTracker as? WorkoutSessionTrackerStub
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    viewModel.quickStart(kind: .outdoorRun)

    await waitFor { viewModel.activeSession != nil }

    viewModel.markSegment()
    viewModel.markSegment()

    await waitFor { viewModel.lapCount == 1 }
    XCTAssertEqual(viewModel.lapCount, 1)
    XCTAssertFalse(viewModel.isRecordingSegment)

    if let tracker {
      let sessionID = try XCTUnwrap(viewModel.activeSession?.id)
      let storedEvents = await tracker.events
      let laps = storedEvents[sessionID] ?? []
      XCTAssertEqual(laps.count, 1)
    } else {
      XCTFail("Expected WorkoutSessionTrackerStub")
    }
  }

  func testAuthorizationRemainsAuthorizedWhenOnlyOptionalMetricsDenied() async throws {
    let status = WorkoutAuthorizationStatus(
      state: .authorized,
      deniedMetrics: [.vo2Max]
    )
    let services = WorkoutServices.inMemoryStub(authorizationStatus: status)
    let viewModel = makeViewModel(services: services)

    await viewModel.refreshAuthorization()

    XCTAssertTrue(viewModel.authorization.isAuthorized)
    XCTAssertTrue(viewModel.authorization.hasOptionalLimitations)
    XCTAssertEqual(viewModel.authorization.deniedOptionalMetrics, [.vo2Max])
  }

  func testRequestAuthorizationRebuildsSelectionItemsAfterGrant() async throws {
    let initialStatus = WorkoutAuthorizationStatus(state: .notDetermined)
    let grantedStatus = WorkoutAuthorizationStatus(state: .authorized)
    let authorizationManager = AuthorizationManagerSwitchingStub(
      initialStatus: initialStatus,
      requestResult: grantedStatus
    )

    var services = WorkoutServices.inMemoryStub(authorizationStatus: initialStatus)
    services.authorizationManager = authorizationManager

    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    XCTAssertTrue(viewModel.selectionItems.contains(where: { $0.id == .authorization }))

    viewModel.requestAuthorization()

    await waitFor {
      !viewModel.selectionItems.contains(where: { $0.id == .authorization })
    }

    XCTAssertEqual(viewModel.authorization.state, .authorized)
    XCTAssertFalse(viewModel.selectionItems.contains(where: { $0.id == .authorization }))
  }

  func testStartSelectionBlocksWhenAuthorizationMissing() async throws {
    let unauthorizedStatus = WorkoutAuthorizationStatus(state: .notDetermined)
    var services = WorkoutServices.inMemoryStub(authorizationStatus: unauthorizedStatus)
    let tracker = try XCTUnwrap(services.sessionTracker as? WorkoutSessionTrackerStub)
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()

    let item = try XCTUnwrap(viewModel.selectionItems.first(where: { $0.quickStartKind == .outdoorRun }))
    viewModel.startSelection(for: item)

    await waitFor {
      if case .error(_, let error) = viewModel.presentationState {
        return error == .authorizationDenied
      }
      return false
    }

    let storedSessions = await tracker.sessions
    XCTAssertTrue(storedSessions.isEmpty)
    XCTAssertEqual(viewModel.errorMessage, WorkoutError.authorizationDenied.errorDescription)
    XCTAssertEqual(viewModel.recoveryAction, WorkoutError.authorizationDenied.recoveryAction)
  }

  func testLiveMetricsStreamUpdatesSessionAndClearsOnEnd() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let viewModel = makeViewModel(services: services)
    let tracker = try XCTUnwrap(services.sessionTracker as? WorkoutSessionTrackerStub)

    await viewModel.bootstrap()
    viewModel.quickStart(kind: .outdoorRun)

    await waitFor { viewModel.activeSession != nil }
    let sessionID = try XCTUnwrap(viewModel.activeSession?.id)

    let metrics = WorkoutLiveMetrics(
      sessionId: sessionID,
      elapsedTime: 120,
      totalDistance: 1_500,
      activeEnergy: 42,
      heartRate: 137
    )

    await tracker.sendLiveMetrics(metrics)
    await waitFor { viewModel.liveMetrics?.totalDistance == metrics.totalDistance }

    XCTAssertEqual(viewModel.liveMetrics, metrics)
    XCTAssertEqual(viewModel.activeSession?.summary.totalDistance, metrics.totalDistance)
    XCTAssertEqual(viewModel.activeSession?.summary.activeEnergy, metrics.activeEnergy)
    XCTAssertEqual(viewModel.activeSession?.summary.duration, metrics.elapsedTime)
    XCTAssertEqual(viewModel.activeSession?.summary.averageHeartRate, metrics.heartRate)

    viewModel.endActiveSession()

    await waitFor { viewModel.activeSession == nil }
    XCTAssertNil(viewModel.liveMetrics)
  }

  private func makeViewModel(
    services: WorkoutServices,
    dwellConfiguration: WorkoutSelectionDwellConfiguration = WorkoutSelectionDwellConfiguration(dwellDuration: 0.05, velocityThreshold: 1.0)
  ) -> WorkoutModeViewModel {
    let suiteName = "WorkoutModeViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    let controller = AppModeController(defaults: defaults, storageKey: "mode_pref")
    return WorkoutModeViewModel(
      services: services,
      appModeController: controller,
      dwellConfiguration: dwellConfiguration
    )
  }

  private func waitFor(
    _ condition: @escaping () -> Bool,
    timeout: TimeInterval = 1,
    pollingInterval: UInt64 = 20_000_000
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      await Task.yield()
      try? await Task.sleep(nanoseconds: pollingInterval)
    }
    if !condition() {
      XCTFail("Condition not met within timeout")
    }
  }
}

@MainActor
private final class FailingSessionTracker: WorkoutSessionTracking {
  func startSession(configuration: WorkoutSessionConfiguration) async throws -> WorkoutSession {
    throw WorkoutSessionError.collectionBeginFailed
  }

  func pauseSession(id: UUID) async throws {}

  func resumeSession(id: UUID) async throws {}

  func endSession(id: UUID, at date: Date) async throws -> WorkoutSession {
    throw WorkoutSessionError.sessionNotFound
  }

  func recordEvent(_ event: WorkoutEvent, sessionId: UUID) async {}

  func liveMetricsStream() -> AsyncStream<WorkoutLiveMetrics> {
    AsyncStream { continuation in
      continuation.finish()
    }
  }
}

@MainActor
private final class FlakySessionTracker: WorkoutSessionTracking {
  private var failuresRemaining: Int
  private let underlying = WorkoutSessionTrackerStub()

  init(failuresBeforeSuccess: Int) {
    self.failuresRemaining = failuresBeforeSuccess
  }

  func startSession(configuration: WorkoutSessionConfiguration) async throws -> WorkoutSession {
    if failuresRemaining > 0 {
      failuresRemaining -= 1
      throw WorkoutSessionError.collectionBeginFailed
    }
    return try await underlying.startSession(configuration: configuration)
  }

  func pauseSession(id: UUID) async throws {
    try await underlying.pauseSession(id: id)
  }

  func resumeSession(id: UUID) async throws {
    try await underlying.resumeSession(id: id)
  }

  func endSession(id: UUID, at date: Date) async throws -> WorkoutSession {
    try await underlying.endSession(id: id, at: date)
  }

  func recordEvent(_ event: WorkoutEvent, sessionId: UUID) async {
    await underlying.recordEvent(event, sessionId: sessionId)
  }

  func liveMetricsStream() -> AsyncStream<WorkoutLiveMetrics> {
    underlying.liveMetricsStream()
  }
}

private final actor AuthorizationManagerSwitchingStub: WorkoutAuthorizationManaging {
  private var currentStatus: WorkoutAuthorizationStatus
  private let requestResult: WorkoutAuthorizationStatus

  init(initialStatus: WorkoutAuthorizationStatus, requestResult: WorkoutAuthorizationStatus) {
    self.currentStatus = initialStatus
    self.requestResult = requestResult
  }

  func authorizationStatus() async -> WorkoutAuthorizationStatus {
    currentStatus
  }

  func requestAuthorization() async throws -> WorkoutAuthorizationStatus {
    currentStatus = requestResult
    return requestResult
  }
}
