//
//  SettingsViewModel.swift
//  RefWatchCore
//
//  ViewModel controlling the logic for user settings.
//

import Foundation
import Observation

@Observable
public final class SettingsViewModel {
    public var settings = Settings()
    public init() {}
    
    public func updatePeriodDuration(_ duration: Int) {
        settings.periodDuration = duration
    }
    
    public func updateExtraTimeDuration(_ duration: Int) {
        settings.extraTimeDuration = duration
    }

    // Substitution settings methods
    public func updateConfirmSubstitutions(_ confirm: Bool) {
        settings.confirmSubstitutions = confirm
    }

    public func updateSubstitutionOrder(_ playerOffFirst: Bool) {
        settings.substitutionOrderPlayerOffFirst = playerOffFirst
    }
}
