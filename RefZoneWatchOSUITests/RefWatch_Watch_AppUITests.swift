//
//  RefWatch_Watch_AppUITests.swift
//  RefZone Watch AppUITests
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
    func testWorkoutControlsAreHittable() throws {
        let app = XCUIApplication()
        app.launch()

        // Ensure we're on the match launcher before switching modes
        XCTAssertTrue(app.staticTexts["Start Match"].waitForExistence(timeout: 3))

        // Open the mode switcher from the toolbar chevron
        let modeButton = app.buttons["chevron.backward"].exists ? app.buttons["chevron.backward"] : app.buttons["Back"]
        XCTAssertTrue(modeButton.waitForExistence(timeout: 2))
        modeButton.tap()

        // Select Workout mode
        let workoutOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Workout'")).firstMatch
        XCTAssertTrue(workoutOption.waitForExistence(timeout: 3))
        workoutOption.tap()

        // Start a quick workout session
        let quickStart = app.buttons["Outdoor Run"].exists ? app.buttons["Outdoor Run"] : app.buttons.firstMatch
        XCTAssertTrue(quickStart.waitForExistence(timeout: 4))
        quickStart.tap()

        // Verify primary control tiles are hittable
        let pauseButton = app.buttons["Pause"].exists ? app.buttons["Pause"] : app.buttons["Resume"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 6))
        XCTAssertTrue(pauseButton.isHittable)

        let segmentButton = app.buttons["Segment"]
        XCTAssertTrue(segmentButton.waitForExistence(timeout: 2))
        XCTAssertTrue(segmentButton.isHittable)

        let endButton = app.buttons["End"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 2))
        XCTAssertTrue(endButton.isHittable)

        // Navigate back to match mode to avoid impacting subsequent tests
        if app.buttons["chevron.backward"].waitForExistence(timeout: 2) {
            app.buttons["chevron.backward"].tap()
            let matchOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Match'"))
                .firstMatch
            if matchOption.waitForExistence(timeout: 2) {
                matchOption.tap()
            }
        }
    }

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
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].isHittable)
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
        timer.press(forDuration: 1.0)
        let endMatchAction = app.buttons["End Match"]
        if endMatchAction.waitForExistence(timeout: 3) {
            endMatchAction.tap()
        } else if app.staticTexts["End Match"].waitForExistence(timeout: 1) {
            app.staticTexts["End Match"].tap()
        }
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
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].isHittable)
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
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].isHittable)
        app.buttons["kickoffConfirmButton"].tap()

        // End second half (regulation)
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET1 kickoff: select home and confirm
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].isHittable)
        app.buttons["kickoffConfirmButton"].tap()

        // End ET1
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET2 kickoff: confirm (default selected)
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].isHittable)
        app.buttons["kickoffConfirmButton"].tap()

        // End ET2 -> penalties
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Penalty first-kicker prompt: choose Home (stable identifier), else Away
        if app.buttons["firstKickerHomeBtn"].waitForExistence(timeout: 3) { app.buttons["firstKickerHomeBtn"].tap() }
        else if app.buttons["firstKickerAwayBtn"].exists { app.buttons["firstKickerAwayBtn"].tap() }

        // Early decision sequence: 3× (home score, away miss) => decided after 3 each
        for _ in 0..<3 {
            XCTAssertTrue(app.buttons["homeScorePenaltyBtn"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["homeScorePenaltyBtn"].isHittable)
            app.buttons["homeScorePenaltyBtn"].tap()
            XCTAssertTrue(app.buttons["awayMissPenaltyBtn"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["awayMissPenaltyBtn"].isHittable)
            app.buttons["awayMissPenaltyBtn"].tap()
        }

        // End shootout via panel long-press
        let homePenaltyPanel = app.otherElements["homePenaltyPanel"]
        XCTAssertTrue(homePenaltyPanel.waitForExistence(timeout: 3))
        homePenaltyPanel.press(forDuration: 1.0)
        if app.buttons["End Shootout"].waitForExistence(timeout: 3) {
            app.buttons["End Shootout"].tap()
        } else if app.staticTexts["End Shootout"].exists {
            app.staticTexts["End Shootout"].tap()
        }

        // Full time: end match
        timer.press(forDuration: 1.0)
        let endMatchButton = app.buttons["End Match"]
        if endMatchButton.waitForExistence(timeout: 3) {
            endMatchButton.tap()
        } else if app.staticTexts["End Match"].exists {
            app.staticTexts["End Match"].tap()
        }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Back to idle
        XCTAssertTrue(app.staticTexts["Start Match"].waitForExistence(timeout: 3))
    }
}

// MARK: - Penalties Edge Cases
extension RefWatch_Watch_AppUITests {
    @MainActor
    func testPenalty_FirstKicker_DoubleTap_IsSafe() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to match creation
        if app.buttons["Start Match"].exists { app.buttons["Start Match"].tap() } else { app.staticTexts["Start Match"].tap() }
        if app.buttons["Create Match"].exists { app.buttons["Create Match"].tap() } else { app.staticTexts["Create Match"].tap() }

        // Enable ET + Penalties and start
        if app.switches["Extra Time"].waitForExistence(timeout: 2) { app.switches["Extra Time"].tap() }
        if app.switches["Penalties"].waitForExistence(timeout: 2) { app.switches["Penalties"].tap() }
        XCTAssertTrue(app.buttons["startMatchButton"].waitForExistence(timeout: 3))
        app.buttons["startMatchButton"].tap()

        // Kickoff first half
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        app.buttons["kickoffConfirmButton"].tap()

        // End both regulation halves
        let timer = app.otherElements["timerArea"]
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        app.buttons["kickoffConfirmButton"].tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET1 kickoff + end
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        app.buttons["kickoffConfirmButton"].tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET2 kickoff confirm, then end -> penalties
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        app.buttons["kickoffConfirmButton"].tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // First-kicker view: rapidly tap Home twice; ensure we end up in penalties screen
        XCTAssertTrue(app.buttons["firstKickerHomeBtn"].waitForExistence(timeout: 3))
        app.buttons["firstKickerHomeBtn"].tap()
        app.buttons["firstKickerHomeBtn"].tap()

        // Validate we're on penalties and can interact
        XCTAssertTrue(app.buttons["homeScorePenaltyBtn"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPenalty_FirstKicker_Presented_AfterSheetDismiss() throws {
        let app = XCUIApplication()
        app.launch()

        // Start -> Create -> Enable ET+Penalties -> Start
        if app.buttons["Start Match"].exists { app.buttons["Start Match"].tap() } else { app.staticTexts["Start Match"].tap() }
        if app.buttons["Create Match"].exists { app.buttons["Create Match"].tap() } else { app.staticTexts["Create Match"].tap() }
        if app.switches["Extra Time"].waitForExistence(timeout: 2) { app.switches["Extra Time"].tap() }
        if app.switches["Penalties"].waitForExistence(timeout: 2) { app.switches["Penalties"].tap() }
        XCTAssertTrue(app.buttons["startMatchButton"].waitForExistence(timeout: 3))
        app.buttons["startMatchButton"].tap()

        // Kickoff select + confirm
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        app.buttons["kickoffConfirmButton"].tap()

        // Drive to penalties using actions sheet and confirm dialogs
        let timer = app.otherElements["timerArea"]
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        app.buttons["kickoffConfirmButton"].tap()

        // End regulation 2nd half
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET1
        XCTAssertTrue(app.buttons["homeTeamButton"].waitForExistence(timeout: 3))
        app.buttons["homeTeamButton"].tap()
        app.buttons["kickoffConfirmButton"].tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // ET2 kickoff confirm, then end -> penalties first-kicker screen should appear after sheet dismissal
        XCTAssertTrue(app.buttons["kickoffConfirmButton"].waitForExistence(timeout: 3))
        app.buttons["kickoffConfirmButton"].tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        timer.press(forDuration: 1.0)
        if app.buttons["End Half"].exists { app.buttons["End Half"].tap() }
        if app.buttons["Yes"].waitForExistence(timeout: 2) { app.buttons["Yes"].tap() }

        // Assert first-kicker buttons appear (ensuring routing after dismissal is working)
        XCTAssertTrue(app.buttons["firstKickerHomeBtn"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["firstKickerAwayBtn"].exists)
    }
}
