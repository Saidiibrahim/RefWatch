//
//  SettingsViewModel.swift
//  RefereeAssistant
//
//  Description: ViewModel controlling the logic for user settings.
//

import Foundation
import SwiftUI

@Observable final class SettingsViewModel {
    var settings = Settings()
    
    func updatePeriodDuration(_ duration: Int) {
        settings.periodDuration = duration
    }
    
    func updateExtraTimeDuration(_ duration: Int) {
        settings.extraTimeDuration = duration
    }
}
