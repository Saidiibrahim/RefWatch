//
//  SettingsTabView.swift
//  RefWatchiOS
//
//  Placeholder for app settings & sync controls
//

import SwiftUI

struct SettingsTabView: View {
    @State private var defaultPeriod: Int = 45
    @State private var extraTime: Bool = false
    @State private var penaltyRounds: Int = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults") {
                    Stepper(value: $defaultPeriod, in: 30...60, step: 5) {
                        LabeledContent("Regulation Period", value: "\(defaultPeriod) min")
                    }
                    Toggle("Extra Time Enabled", isOn: $extraTime)
                    Stepper(value: $penaltyRounds, in: 3...10) {
                        LabeledContent("Penalty Rounds", value: "\(penaltyRounds)")
                    }
                }

                Section("Sync") {
                    LabeledContent("Watch", value: "Connected • Placeholder")
                    Button { } label: { Label("Resync Now", systemImage: "arrow.clockwise") }
                }

                Section("Data") {
                    Button(role: .destructive) { } label: { Label("Wipe Local Data", systemImage: "trash") }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview { SettingsTabView() }

