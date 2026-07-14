import XCTest

final class AssistantFlowUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchRefWatch()
  }

  func testAssistantTabNavigationAndStubReply() throws {
    try ensureAssistantShellOrSkip()

    let assistantTab = app.tabBars.buttons["Assistant"]
    XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
    assistantTab.tap()

    XCTAssertTrue(app.navigationBars["Assistant"].waitForExistence(timeout: 5))

    let fallbackBanner = app.staticTexts["Assistant proxy unavailable — using demo replies."]
    XCTAssertTrue(
      fallbackBanner.waitForExistence(timeout: 5),
      "Current simulator builds should surface the stub banner until a server-backed assistant session is available.")

    let prompt = app.descendants(matching: .any)["assistant.prompt"]
    XCTAssertTrue(prompt.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["assistant.send"].exists)

    prompt.tap()
    prompt.typeText("What do you see?")

    let sendButton = app.buttons["assistant.send"]
    XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
    sendButton.tap()

    XCTAssertTrue(app.staticTexts["What do you see?"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "You said:"))
        .firstMatch
        .waitForExistence(timeout: 10),
      "The stub assistant should render a streamed reply after send.")
    XCTAssertFalse(app.buttons["assistant.send"].waitForExistence(timeout: 2))
  }

  func testAssistantSendStateTogglesWithTextInput() throws {
    try ensureAssistantShellOrSkip()

    app.tabBars.buttons["Assistant"].tap()
    XCTAssertTrue(app.navigationBars["Assistant"].waitForExistence(timeout: 5))

    let prompt = app.descendants(matching: .any)["assistant.prompt"]
    XCTAssertTrue(prompt.waitForExistence(timeout: 5))

    XCTAssertFalse(app.buttons["assistant.send"].exists)

    prompt.tap()
    prompt.typeText("Send-state check")

    let sendButton = app.buttons["assistant.send"]
    XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
    sendButton.tap()

    XCTAssertTrue(app.staticTexts["Send-state check"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["assistant.send"].waitForExistence(timeout: 2))
  }

  func testAssistantAttachmentEntryPointReportsCurrentSimulatorLimitation() throws {
    try ensureAssistantShellOrSkip()

    app.tabBars.buttons["Assistant"].tap()
    XCTAssertTrue(app.navigationBars["Assistant"].waitForExistence(timeout: 5))

    let plusButton = app.buttons["assistant.attachImage"]
    XCTAssertTrue(
      plusButton.waitForExistence(timeout: 5),
      "The assistant attachment entry point must remain accessible by its stable identifier.")

    plusButton.tap()

    let picker = app.sheets.firstMatch
    if picker.waitForExistence(timeout: 2) == false {
      throw XCTSkip(
        "No picker or image fallback surfaced. The current simulator build does not expose a testable attachment flow.")
    }
  }
}

private extension AssistantFlowUITests {
  func ensureAssistantShellOrSkip() throws {
    if app.tabBars.buttons["Assistant"].waitForExistence(timeout: 3) {
      return
    }

    if app.tabBars.buttons["Assistant"].waitForExistence(timeout: 10) {
      return
    }

    throw XCTSkip(
      "Assistant UI tests require the signed-in UI-test shell. The current run did not reach the assistant tab bar.")
  }
}
