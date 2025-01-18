//
//  Settings.swift
//  RefereeAssistant
//
//  Description: Data model representing user settings.
//

import Foundation

struct Settings {
    var exampleSetting: Bool
    var periodDuration: Int
    var extraTimeDuration: Int
    
    init(
        exampleSetting: Bool = false,
        periodDuration: Int = 45,
        extraTimeDuration: Int = 15
    ) {
        self.exampleSetting = exampleSetting
        self.periodDuration = periodDuration
        self.extraTimeDuration = extraTimeDuration
    }
}
