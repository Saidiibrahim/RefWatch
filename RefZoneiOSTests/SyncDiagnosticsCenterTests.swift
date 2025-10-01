import XCTest
@testable import RefZoneiOS
import RefWatchCore

final class SyncDiagnosticsCenterTests: XCTestCase {
  func testSyncStatusUpdateRefreshesPublishedState() {
    let notificationCenter = NotificationCenter()
    let fixedNow = Date(timeIntervalSince1970: 1_234)
    let diagnostics = SyncDiagnosticsCenter(center: notificationCenter, clock: { fixedNow })

    let nextRetry = Date(timeIntervalSince1970: 2_345)
    notificationCenter.post(
      name: .syncStatusUpdate,
      object: nil,
      userInfo: [
        "component": "match_history",
        "pendingPushes": 3,
        "pendingDeletions": 1,
        "signedIn": true,
        "nextRetry": nextRetry,
        "timestamp": fixedNow
      ]
    )

    XCTAssertEqual(diagnostics.matchStatus.pendingPushes, 3)
    XCTAssertEqual(diagnostics.matchStatus.pendingDeletions, 1)
    XCTAssertEqual(diagnostics.matchStatus.nextRetry, nextRetry)
    XCTAssertTrue(diagnostics.matchStatus.signedIn)
    XCTAssertEqual(diagnostics.matchStatus.lastUpdated, fixedNow)
  }

  func testDifferentComponentsUpdateSeparateStatus() {
    let notificationCenter = NotificationCenter()
    let diagnostics = SyncDiagnosticsCenter(center: notificationCenter)

    notificationCenter.post(
      name: .syncStatusUpdate,
      object: nil,
      userInfo: [
        "component": "team_library",
        "pendingPushes": 2,
        "pendingDeletions": 0,
        "signedIn": false,
        "timestamp": Date()
      ]
    )

    XCTAssertEqual(diagnostics.teamStatus.pendingPushes, 2)
    XCTAssertEqual(diagnostics.matchStatus.pendingPushes, 0)

    notificationCenter.post(
      name: .syncStatusUpdate,
      object: nil,
      userInfo: [
        "component": "schedule",
        "pendingPushes": 1,
        "pendingDeletions": 1,
        "signedIn": true,
        "timestamp": Date()
      ]
    )

    XCTAssertEqual(diagnostics.scheduleStatus.pendingPushes, 1)
    XCTAssertEqual(diagnostics.scheduleStatus.pendingDeletions, 1)
    XCTAssertTrue(diagnostics.scheduleStatus.signedIn)
  }
}
