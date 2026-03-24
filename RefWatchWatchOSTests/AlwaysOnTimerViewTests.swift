import XCTest
import RefWatchCore
@testable import RefWatch_Watch_App

@MainActor
final class AlwaysOnTimerViewTests: XCTestCase {
  func testDisplayContentUsesHalfTimeElapsedDuringHalfTime() {
    let model = FakeTimerFaceModel()
    model.isHalfTime = true
    model.matchTime = "45:00"
    model.halfTimeElapsed = "03:12"

    let content = AlwaysOnTimerView.displayContent(for: model)

    XCTAssertEqual(content.headerText, "HT")
    XCTAssertEqual(content.primaryTime, "03:12")
    XCTAssertNil(content.secondaryTime)
    XCTAssertEqual(content.accessibilityLabel, "Half time")
    XCTAssertEqual(content.accessibilityValue, "03:12")
  }

  func testDisplayContentUsesMatchAndRemainingTimeOutsideHalfTime() {
    let model = FakeTimerFaceModel()
    model.isHalfTime = false
    model.matchTime = "67:14"
    model.periodTimeRemaining = "22:46"

    let content = AlwaysOnTimerView.displayContent(for: model)

    XCTAssertNil(content.headerText)
    XCTAssertEqual(content.primaryTime, "67:14")
    XCTAssertEqual(content.secondaryTime, "22:46")
    XCTAssertEqual(content.accessibilityLabel, "Match time")
    XCTAssertEqual(content.accessibilityValue, "67:14")
  }

  func testDisplayContentUsesHalfTimeHeaderWhileWaitingToStartHalfTime() {
    let model = FakeTimerFaceModel()
    model.waitingForHalfTimeStart = true
    model.matchTime = "45:00"
    model.halfTimeElapsed = "00:00"

    let content = AlwaysOnTimerView.displayContent(for: model)

    XCTAssertEqual(content.headerText, "HT")
    XCTAssertEqual(content.primaryTime, "45:00")
    XCTAssertNil(content.secondaryTime)
    XCTAssertEqual(content.accessibilityLabel, "Half time")
    XCTAssertEqual(content.accessibilityValue, "45:00")
  }

  func testDisplayContentUsesExpiredHeaderDuringPendingBoundaryDecision() {
    let model = FakeTimerFaceModel()
    model.pendingPeriodBoundaryDecision = .firstHalf
    model.matchTime = "45:18"
    model.formattedStoppageTime = "00:18"

    let content = AlwaysOnTimerView.displayContent(for: model)

    XCTAssertEqual(content.headerText, "EXP")
    XCTAssertEqual(content.primaryTime, "45:18")
    XCTAssertEqual(content.secondaryTime, "+00:18")
    XCTAssertEqual(content.accessibilityLabel, "Time expired")
    XCTAssertEqual(content.accessibilityValue, "45:18, +00:18")
  }
}

@MainActor
private final class FakeTimerFaceModel: TimerFaceModel {
  var matchTime = "00:00"
  var periodTime = "00:00"
  var periodTimeRemaining = "00:00"
  var halfTimeElapsed = "00:00"
  var isInStoppage = false
  var formattedStoppageTime = "00:00"
  var isPaused = false
  var isHalfTime = false
  var waitingForHalfTimeStart = false
  var pendingPeriodBoundaryDecision: PendingPeriodBoundaryDecision? = nil
  var isMatchInProgress = false
  var currentPeriod = 1

  func pauseMatch() {}
  func resumeMatch() {}
  func startHalfTimeManually() {}
  func beginStoppage() {}
  func endStoppage() {}
}
