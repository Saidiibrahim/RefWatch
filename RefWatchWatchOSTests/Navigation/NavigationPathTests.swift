//
//  NavigationPathTests.swift
//  RefWatch Watch AppTests
//
//  Verifies the canonical path helpers and reducer behaviour that keep the
//  `NavigationStack` state in sync with lifecycle transitions.
//

import XCTest
@testable import RefWatch_Watch_App
@testable import RefWatchCore

final class NavigationPathTests: XCTestCase {
  private var reducer: MatchNavigationReducer!

  override func setUp() {
    super.setUp()
    reducer = MatchNavigationReducer()
  }

  func testCanonicalPathsRemainStable() {
    XCTAssertEqual(MatchRoute.startFlow.canonicalPath, [.startFlow])
    XCTAssertEqual(MatchRoute.savedMatches.canonicalPath, [.startFlow, .savedMatches])
    XCTAssertEqual(MatchRoute.createMatch.canonicalPath, [.startFlow, .createMatch])
  }

  func testIdleToActiveClearsPath() {
    var path: [MatchRoute] = [.startFlow, .createMatch]
    reducer.reduce(path: &path, from: .idle, to: .kickoffFirstHalf)
    XCTAssertTrue(path.isEmpty)
  }

  func testActiveToIdleClearsPath() {
    var path: [MatchRoute] = [.startFlow, .savedMatches]
    reducer.reduce(path: &path, from: .setup, to: .idle)
    XCTAssertTrue(path.isEmpty)
  }

  func testIdleToIdlePreservesPath() {
    var path: [MatchRoute] = [.startFlow]
    reducer.reduce(path: &path, from: .idle, to: .idle)
    XCTAssertEqual(path, [.startFlow])
  }

  func testCanonicalHelperIsIdempotent() {
    var path: [MatchRoute] = []
    for _ in 0 ..< 3 {
      path = MatchRoute.createMatch.canonicalPath
    }
    XCTAssertEqual(path, [.startFlow, .createMatch])
  }
}
