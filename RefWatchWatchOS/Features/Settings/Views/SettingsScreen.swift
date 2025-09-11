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
        List {
            Section("Substitutions") {
                // Confirmation toggle - default is on
                Toggle(isOn: $settingsViewModel.settings.confirmSubstitutions) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Confirm Substitutions")
                            .font(.system(size: 14, weight: .medium))
//                        Text("Show confirmation screen before recording")
//                            .font(.system(size: 12))
//                            .foregroundColor(.secondary)
                    }
                }
                
                // Substitution order picker - navigationLink style
                Picker("Recording Order", selection: $settingsViewModel.settings.substitutionOrderPlayerOffFirst) {
                    Label("Player Off First", systemImage: "arrow.left.circle")
                        .tag(true)
                    Label("Player On First", systemImage: "arrow.right.circle")
                        .tag(false)
                }
                .pickerStyle(.navigationLink)
            }
            
            Section("General") {
                // Keep the example setting for now
                Toggle(isOn: $settingsViewModel.settings.exampleSetting) {
                    Text("Example Setting")
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        SettingsScreen(settingsViewModel: SettingsViewModel())
    }
}
