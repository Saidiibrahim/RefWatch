//
//  TestEnvironment.swift
//  RefWatchiOS
//
//  Small helper to detect XCTest runs without pulling in XCTest.
//

import Foundation

enum TestEnvironment {
  static var isRunningTests: Bool {
    let env = ProcessInfo.processInfo.environment
    return env["XCTestConfigurationFilePath"] != nil
      || env["XCTestSessionIdentifier"] != nil
  }
}
