import XCTest

extension XCUIApplication {
  func launchRefWatch(authState: String = "signed_in") {
    launchArguments.append("--refwatch-ui-testing")
    launchEnvironment["REFWATCH_UI_TEST_PROCESS"] = "1"
    launchEnvironment["REFWATCH_UI_TEST_AUTH_STATE"] = authState
    launch()
  }
}
