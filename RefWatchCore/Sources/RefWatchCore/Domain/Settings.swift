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
    
    // Substitution settings
    public var confirmSubstitutions: Bool
    public var substitutionOrderPlayerOffFirst: Bool
    
    public init(
        exampleSetting: Bool = false,
        periodDuration: Int = 45,
        extraTimeDuration: Int = 15,
        confirmSubstitutions: Bool = true,
        substitutionOrderPlayerOffFirst: Bool = true
    ) {
        self.exampleSetting = exampleSetting
        self.periodDuration = periodDuration
        self.extraTimeDuration = extraTimeDuration
        self.confirmSubstitutions = confirmSubstitutions
        self.substitutionOrderPlayerOffFirst = substitutionOrderPlayerOffFirst
    }
}

