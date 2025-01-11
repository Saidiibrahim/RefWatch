//
//  Settings.swift
//  RefereeAssistant
//
//  Description: Data model representing user settings.
//

import Foundation

struct Settings {
    var exampleSetting: Bool
    
    init(exampleSetting: Bool = false) {
        self.exampleSetting = exampleSetting
    }
}
