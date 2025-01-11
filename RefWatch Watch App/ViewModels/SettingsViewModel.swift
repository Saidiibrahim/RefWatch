//
//  SettingsViewModel.swift
//  RefereeAssistant
//
//  Description: ViewModel controlling the logic for user settings.
//

import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var settings = Settings()
    
    // This example toggles a single setting. Expand for more complex logic.
    var exampleSetting: Bool {
        get { settings.exampleSetting }
        set { settings.exampleSetting = newValue }
    }
    
    init() {
        // Potentially load saved settings or defaults here
    }
    
    // Example of saving settings or any other settings-based logic
    func saveSettings() {
        // Add your saving logic here (UserDefaults, CloudKit, etc.)
    }
}
