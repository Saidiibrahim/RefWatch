//
//  TestEnvironment.swift
//  RefWatchiOS
//
//  Small helper to detect XCTest runs without pulling in XCTest.
//

import Foundation

enum TestEnvironment {
  private static let uiTestAuthStateKey = "REFWATCH_UI_TEST_AUTH_STATE"

  static var isRunningTests: Bool {
    let env = ProcessInfo.processInfo.environment
    return env["XCTestConfigurationFilePath"] != nil
      || env["XCTestSessionIdentifier"] != nil
  }

  static var isRunningUnitTests: Bool {
    guard self.isRunningTests else { return false }
    return Bundle.allBundles.contains { bundle in
      bundle.bundleURL.pathExtension == "xctest"
    }
  }

  static var isRunningUITests: Bool {
    self.isRunningTests && self.isRunningUnitTests == false
  }

  static var launchesSignedInUITestShell: Bool {
    self.isRunningUITests
      && ProcessInfo.processInfo.environment[self.uiTestAuthStateKey] == "signed_in"
  }
}
