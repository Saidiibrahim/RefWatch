//
//  TimerFaceSettingsView.swift
//  RefWatchWatchOS
//
//  Description: Screen to select the active timer face using AppStorage.
//

import SwiftUI

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

