//
//  LifecycleTransitionMatrixTests.swift
//  RefZone Watch AppTests
//
//  Exercises the navigation reducer across every lifecycle transition to
//  guarantee the start-flow stack is cleared at the correct times.
//

import XCTest
@testable import RefZone_Watch_App

final class LifecycleTransitionMatrixTests: XCTestCase {
  private let allStates: [MatchLifecycleCoordinator.State] = [
    .idle,
    .setup,
    .kickoffFirstHalf,
    .kickoffSecondHalf,
    .kickoffExtraTimeFirstHalf,
    .kickoffExtraTimeSecondHalf,
    .choosePenaltyFirstKicker,
    .penalties,
    .finished
  ]

  private var reducer: MatchNavigationReducer!

  override func setUp() {
    super.setUp()
    reducer = MatchNavigationReducer()
  }

  func testLeavingIdleClearsAnyStackedRoutes() {
    for destination in allStates where destination != .idle {
      var path: [MatchRoute] = [.startFlow, .createMatch]
      reducer.reduce(path: &path, from: .idle, to: destination)
      XCTAssertTrue(path.isEmpty, "Expected path cleared when leaving idle toward \(destination)")
    }
  }

  func testReturningToIdleClearsRoutesRegardlessOfOrigin() {
    for origin in allStates where origin != .idle {
      var path: [MatchRoute] = [.startFlow, .savedMatches]
      reducer.reduce(path: &path, from: origin, to: .idle)
      XCTAssertTrue(path.isEmpty, "Expected path cleared when returning to idle from \(origin)")
    }
  }

  func testActiveToActiveDoesNotMutateEmptyPath() {
    for origin in allStates where origin != .idle {
      for destination in allStates where destination != .idle {
        var path: [MatchRoute] = []
        reducer.reduce(path: &path, from: origin, to: destination)
        XCTAssertTrue(path.isEmpty, "Expected path to remain empty transitioning \(origin) → \(destination)")
      }
    }
  }

  func testReducerNeverIntroducesRoutes() {
    for origin in allStates {
      for destination in allStates {
        var path: [MatchRoute] = []
        reducer.reduce(path: &path, from: origin, to: destination)
        XCTAssertEqual(path.count, 0, "Reducer should not append routes for \(origin) → \(destination)")
      }
    }
  }
}
