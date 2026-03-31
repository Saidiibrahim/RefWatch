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

  static var isRunningPreviews: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }

  static var launchesSignedInUITestShell: Bool {
    #if DEBUG
      ProcessInfo.processInfo.environment[self.uiTestAuthStateKey] == "signed_in"
    #else
      false
    #endif
  }

  static var matchSheetImportUITestMode: MatchSheetImportUITestMode? {
    #if DEBUG
      return MatchSheetImportUITestMode(
        rawValue: ProcessInfo.processInfo.environment[self.matchSheetImportModeKey] ?? "")
    #else
      nil
    #endif
  }
}
