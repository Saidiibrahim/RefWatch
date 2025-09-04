//
//  Settings.swift
//  RefWatchCore
//
//  Data model representing user settings.
//

import Foundation

public struct Settings {
    public var exampleSetting: Bool
    public var periodDuration: Int
    public var extraTimeDuration: Int
    
    public init(
        exampleSetting: Bool = false,
        periodDuration: Int = 45,
        extraTimeDuration: Int = 15
    ) {
        self.exampleSetting = exampleSetting
        self.periodDuration = periodDuration
        self.extraTimeDuration = extraTimeDuration
    }
}

