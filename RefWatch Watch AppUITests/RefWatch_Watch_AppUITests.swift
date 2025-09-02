//
//  RefWatch_Watch_AppUITests.swift
//  RefWatch Watch AppUITests
//
//  Created by Ibrahim Saidi on 11/1/2025.
//

import XCTest

final class RefWatch_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

// MARK: - End-to-end lifecycle UI test
extension RefWatch_Watch_AppUITests {
    @MainActor
    func testCreate_Kickoff_Run_EndMatch_Idle() throws {
        let app = XCUIApplication()
        app.launch()

        // Go to Start Match
        if app.buttons["Start Match"].exists {
            app.buttons["Start Match"].tap()
        } else if app.staticTexts["Start Match"].exists {
            app.staticTexts["Start Match"].tap()
        }

        // Open Create Match
        if app.buttons["Create Match"].exists { app.buttons["Create Match"].tap() }
        else { app.staticTexts["Create Match"].tap() }

        // Start Match from settings
        XCTAssertTrue(app.buttons["startMatchButton"].waitForExistence(timeout: 3))
        app.buttons["startMatchButton"].tap()

        // Kickoff: select home and confirm
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        app.buttons["kickoffConfirmButton"].tap()

        // Long-press timer area to open actions
        let timer = app.otherElements["timerArea"]
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)

        // End first half
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        else { app.staticTexts["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Immediately end half-time
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half-Time"].exists { app.buttons["End Half-Time"].tap() }

        // Second half kickoff auto-selects team; confirm
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        app.buttons["kickoffConfirmButton"].tap()

        // End second half
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Full time: end match and return home
        XCTAssertTrue(app.buttons["endMatchButton"].waitForExistence(timeout: 3))
        app.buttons["endMatchButton"].tap()
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Validate we're back to idle
        XCTAssertTrue(app.staticTexts["Start Match"].waitForExistence(timeout: 3))
    }
}

// MARK: - End-to-end lifecycle UI test (ET + Penalties)
extension RefWatch_Watch_AppUITests {
    @MainActor
    func testCreate_Kickoff_ET_Penalties_EndMatch_Idle() throws {
        let app = XCUIApplication()
        app.launch()

        // Start Match entry
        if app.buttons["Start Match"].exists { app.buttons["Start Match"].tap() }
        else if app.staticTexts["Start Match"].exists { app.staticTexts["Start Match"].tap() }

        // Create Match
        if app.buttons["Create Match"].exists { app.buttons["Create Match"].tap() }
        else { app.staticTexts["Create Match"].tap() }

        // Enable Extra Time and Penalties
        if app.switches["Extra Time"].waitForExistence(timeout: 2) { app.switches["Extra Time"].tap() }
        else if app.staticTexts["Extra Time"].exists { app.staticTexts["Extra Time"].tap() }
        if app.switches["Penalties"].waitForExistence(timeout: 2) { app.switches["Penalties"].tap() }
        else if app.staticTexts["Penalties"].exists { app.staticTexts["Penalties"].tap() }

        // Start the match
        XCTAssertTrue(app.buttons["startMatchButton"].waitForExistence(timeout: 3))
        app.buttons["startMatchButton"].tap()

        // Kickoff first half: select home and confirm
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        app.buttons["kickoffConfirmButton"].tap()

        // End first half
        let timer = app.otherElements["timerArea"]
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        else if app.staticTexts["End Half"].exists { app.staticTexts["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // End half-time immediately
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        else if app.staticTexts["End Half-Time"].exists { app.staticTexts["End Half-Time"].tap() }

        // Kickoff second half (auto-selected team); confirm
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        app.buttons["kickoffConfirmButton"].tap()

        // End second half (regulation)
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET1 kickoff: select home and confirm
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        app.buttons["kickoffConfirmButton"].tap()

        // End ET1
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET2 kickoff: confirm (default selected)
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        app.buttons["kickoffConfirmButton"].tap()

        // End ET2 -> penalties
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Penalty first-kicker prompt: choose Home (HOM) if present, else Away (AWA)
        if app.buttons["HOM"].waitForExistence(timeout: 3) { app.buttons["HOM"].tap() }
        else if app.buttons["AWA"].exists { app.buttons["AWA"].tap() }

        // Early decision sequence: 3× (home score, away miss) => decided after 3 each
        for _ in 0..<3 {
            XCTAssertTrue(app.buttons["homeScorePenaltyBtn"].waitForExistence(timeout: 2))
            app.buttons["homeScorePenaltyBtn"].tap()
            XCTAssertTrue(app.buttons["awayMissPenaltyBtn"].waitForExistence(timeout: 2))
            app.buttons["awayMissPenaltyBtn"].tap()
        }

        // End shootout
        XCTAssertTrue(app.buttons["endShootoutButton"].waitForExistence(timeout: 3))
        app.buttons["endShootoutButton"].tap()

        // Full time: end match
        XCTAssertTrue(app.buttons["endMatchButton"].waitForExistence(timeout: 3))
        app.buttons["endMatchButton"].tap()
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Back to idle
        XCTAssertTrue(app.staticTexts["Start Match"].waitForExistence(timeout: 3))
    }
}
