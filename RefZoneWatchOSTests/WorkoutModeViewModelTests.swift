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
  }

  func testPauseAndResumeToggleState() async throws {
    let services = WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    let viewModel = makeViewModel(services: services)

    await viewModel.bootstrap()
    viewModel.quickStart(.outdoorRun)

    await waitFor { viewModel.activeSession != nil }

    viewModel.pauseActiveSession()
    await waitFor { viewModel.isActiveSessionPaused }
    XCTAssertTrue(viewModel.isActiveSessionPaused)

    viewModel.resumeActiveSession()
    await waitFor { viewModel.isActiveSessionPaused == false }
    XCTAssertFalse(viewModel.isActiveSessionPaused)
  }

  private func makeViewModel(services: WorkoutServices) -> WorkoutModeViewModel {
    let suiteName = "WorkoutModeViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    let controller = AppModeController(defaults: defaults, storageKey: "mode_pref")
    return WorkoutModeViewModel(services: services, appModeController: controller)
  }

  private func waitFor(
    _ condition: @escaping @autoclosure () -> Bool,
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
