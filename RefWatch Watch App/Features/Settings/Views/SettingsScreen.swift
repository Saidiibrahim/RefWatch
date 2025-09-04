//
//  SettingsScreen.swift
//  RefereeAssistant
//
//  Description: Main settings page where users can configure app preferences.
//

import SwiftUI
import RefWatchCore

struct SettingsScreen: View {
    @Bindable var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.headline)
                .padding()
            
            // Example of toggling some setting
            Toggle(isOn: $settingsViewModel.settings.exampleSetting) {
                Text("Example Setting")
            }
            .padding()
            
            // Additional settings can be added here
        }
        .navigationTitle("Settings")
    }
}

struct SettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        SettingsScreen(settingsViewModel: SettingsViewModel())
    }
}
