//
//  SettingsTimerFaceUITests.swift
//  RefWatch Watch AppUITests
//

import XCTest

final class SettingsTimerFaceUITests: XCTestCase {

    @MainActor
    func testSettings_TimerFaceRow_NavigatesToPicker() throws {
        let app = XCUIApplication()
        app.launchRefWatch()

        // Open Settings from home
        let settingsRow = app.buttons["settingsRow"]
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Expected the idle navigation list")
        for _ in 0..<6 where settingsRow.exists == false {
            list.swipeUp()
        }
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10), "Expected Settings on the idle surface")
        XCTAssertTrue(settingsRow.isHittable, "Expected Settings to be hittable after scrolling")
        settingsRow.tap()

        // Tap the Timer Face row
        let timerFaceRow = app.buttons["timerFaceRow"]
        let settingsList = app.collectionViews.firstMatch
        XCTAssertTrue(settingsList.waitForExistence(timeout: 10), "Expected the Settings list")
        for _ in 0..<6 where timerFaceRow.exists == false {
            settingsList.swipeUp()
        }
        XCTAssertTrue(timerFaceRow.waitForExistence(timeout: 10), "Expected the Timer Face settings row")
        XCTAssertTrue(timerFaceRow.isHittable, "Expected Timer Face to be hittable after scrolling")
        timerFaceRow.tap()

        // Assert the picker appears on the next screen
        let picker = app.otherElements["timerFacePicker"]
        let title = app.staticTexts["Timer Face"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10) || title.waitForExistence(timeout: 3),
                      "Expected Timer Face picker or title to be visible")
    }
}
