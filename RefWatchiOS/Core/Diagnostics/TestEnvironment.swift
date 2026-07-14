//
//  TestEnvironment.swift
//  RefWatchiOS
//
//  Small helper to detect XCTest runs without pulling in XCTest.
//

import Foundation

enum TestEnvironment {
  private static let uiTestAuthStateKey = "REFWATCH_UI_TEST_AUTH_STATE"
  private static let matchSheetImportModeKey = "REFWATCH_UI_TEST_MATCH_SHEET_IMPORT_MODE"
  private static let uiTestProcessKey = "REFWATCH_UI_TEST_PROCESS"
  private static let uiTestLaunchArgument = "--refwatch-ui-testing"

  static var isRunningTests: Bool {
    let env = ProcessInfo.processInfo.environment
    return env["XCTestConfigurationFilePath"] != nil
      || env["XCTestSessionIdentifier"] != nil
  }

  static var isRunningUnitTests: Bool {
    // The host app is initialized before XCTest loads the test bundle, so inspecting
    // Bundle.allBundles here misclassifies the first test in each runner as production.
    self.isRunningTests && self.isRunningUITests == false
  }

  static var isRunningUITests: Bool {
    let processInfo = ProcessInfo.processInfo
    return processInfo.environment[self.uiTestProcessKey] == "1"
      && processInfo.arguments.contains(self.uiTestLaunchArgument)
  }

  static var isRunningPreviews: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }

  static var launchesSignedInUITestShell: Bool {
    #if DEBUG
      self.isRunningUITests
        && ProcessInfo.processInfo.environment[self.uiTestAuthStateKey] == "signed_in"
    #else
      false
    #endif
  }

  static var launchesUITestShell: Bool {
    #if DEBUG
      guard self.isRunningUITests else { return false }
      let value = ProcessInfo.processInfo.environment[self.uiTestAuthStateKey]
      return value == "signed_in" || value == "signed_out"
    #else
      false
    #endif
  }

  static var matchSheetImportUITestMode: MatchSheetImportUITestMode? {
    #if DEBUG
      guard self.isRunningUITests else { return nil }
      return MatchSheetImportUITestMode(
        rawValue: ProcessInfo.processInfo.environment[self.matchSheetImportModeKey] ?? "")
    #else
      nil
    #endif
  }
}
