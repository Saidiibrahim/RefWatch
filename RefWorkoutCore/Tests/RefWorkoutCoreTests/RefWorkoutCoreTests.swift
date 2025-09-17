import XCTest
@testable import RefWorkoutCore

final class RefWorkoutCoreTests: XCTestCase {
  func testWorkoutPresetTotals() {
    let segments = [
      WorkoutSegment(name: "Warmup", purpose: .warmup, plannedDuration: 600),
      WorkoutSegment(name: "Intervals", purpose: .work, plannedDuration: 1200, plannedDistance: 3000),
      WorkoutSegment(name: "Cooldown", purpose: .cooldown, plannedDuration: 300)
    ]
    let preset = WorkoutPreset(title: "Tempo", kind: .outdoorRun, segments: segments)

    XCTAssertEqual(preset.totalPlannedDuration, 2100)
    XCTAssertEqual(preset.totalPlannedDistance, 3000)
  }

  func testWorkoutSessionDuration() {
    let start = Date()
    let end = start.addingTimeInterval(1800)
    let session = WorkoutSession(
      state: .ended,
      kind: .outdoorRun,
      title: "Evening Run",
      startedAt: start,
      endedAt: end
    )

    XCTAssertFalse(session.isActive)
    XCTAssertTrue(session.isCompleted)
    XCTAssertEqual(session.totalDuration, 1800)
  }

  func testWorkoutMetricConversionMetersToKilometers() {
    let metric = WorkoutMetric(kind: .distance, value: 5000, unit: .meters)
    let converted = metric.converted(to: .kilometers)

    XCTAssertNotNil(converted)
    XCTAssertEqual(converted?.value ?? -1, 5, accuracy: 0.0001)
    XCTAssertEqual(converted?.unit, .kilometers)
  }

  func testWorkoutSessionStateTransitions() {
    var session = WorkoutSession(
      state: .planned,
      kind: .strength,
      title: "Circuit",
      startedAt: Date()
    )

    let activeStart = Date().addingTimeInterval(-600)
    session.markActive(startedAt: activeStart)
    XCTAssertTrue(session.isActive)
    XCTAssertEqual(session.state, .active)
    XCTAssertEqual(session.elapsedDuration(asOf: activeStart.addingTimeInterval(300)), 300, accuracy: 0.001)

    let completionDate = activeStart.addingTimeInterval(900)
    session.complete(at: completionDate)
    XCTAssertTrue(session.isCompleted)
    XCTAssertEqual(session.state, .ended)
    XCTAssertEqual(session.totalDuration, 900)
    XCTAssertEqual(session.elapsedDuration(), 900)
  }
}
