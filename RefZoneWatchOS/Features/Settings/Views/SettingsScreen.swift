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
    // Persisted timer face selection used by TimerView host
    @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue
    
    var body: some View {
        List {
            // Timer settings
            Section("Timer") {
                NavigationLink {
                    TimerFaceSettingsView()
                } label: {
                    HStack {
                        Text("Timer Face")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        // Show current selection
                        Text(TimerFaceStyle.parse(raw: timerFaceStyleRaw).displayName)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("timerFaceCurrentSelection")
                    }
                }
                .accessibilityIdentifier("timerFaceRow")
            }

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

// MARK: - Timer Face Settings

/// A simple screen to select the active timer face.
/// Binds to AppStorage("timer_face_style") so TimerView reflects changes automatically.
struct TimerFaceSettingsView: View {
    @AppStorage("timer_face_style") private var timerFaceStyleRaw: String = TimerFaceStyle.standard.rawValue

    private var selectedStyle: TimerFaceStyle {
        TimerFaceStyle.parse(raw: timerFaceStyleRaw)
    }

    var body: some View {
        List {
            Picker("Timer Face", selection: $timerFaceStyleRaw) {
                ForEach(TimerFaceStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
            .pickerStyle(.inline)
            .accessibilityIdentifier("timerFacePicker")
        }
        .navigationTitle("Timer Face")
    }
}
