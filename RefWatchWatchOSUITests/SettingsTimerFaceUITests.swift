//
//  SettingsTimerFaceUITests.swift
//  RefWatch Watch AppUITests
//

import XCTest

final class SettingsTimerFaceUITests: XCTestCase {

    @MainActor
    func testSettings_TimerFaceRow_NavigatesToPicker() throws {
        let app = XCUIApplication()
        app.launch()

        // Open Settings from home
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
        } else if app.staticTexts["Settings"].exists {
            app.staticTexts["Settings"].tap()
        }

        // Tap the Timer Face row
        if app.otherElements["timerFaceRow"].waitForExistence(timeout: 3) {
            app.otherElements["timerFaceRow"].tap()
        } else if app.buttons["Timer Face"].exists {
            app.buttons["Timer Face"].tap()
        } else if app.staticTexts["Timer Face"].exists {
            app.staticTexts["Timer Face"].tap()
        } else {
            XCTFail("Timer Face row not found")
        }

        // Assert the picker appears on the next screen
        let picker = app.otherElements["timerFacePicker"]
        let title = app.staticTexts["Timer Face"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3) || title.waitForExistence(timeout: 3),
                      "Expected Timer Face picker or title to be visible")
    }
}

