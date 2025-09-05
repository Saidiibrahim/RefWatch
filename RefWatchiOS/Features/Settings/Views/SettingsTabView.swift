//
//  SettingsTabView.swift
//  RefWatchiOS
//
//  Placeholder for app settings & sync controls
//

import SwiftUI
import RefWatchCore

struct SettingsTabView: View {
    @State private var defaultPeriod: Int = 45
    @State private var extraTime: Bool = false
    @State private var penaltyRounds: Int = 5
    @State private var showingInfoAlert = false
    @State private var infoMessage: String = ""

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
                    Button(role: .destructive) { wipeHistory() } label: { Label("Wipe Local Data", systemImage: "trash") }
                }

                #if DEBUG
                Section("Debug") {
                    Button { seedDemoHistory() } label: { Label("Seed Demo History", systemImage: "sparkles") }
                }
                #endif
            }
            .navigationTitle("Settings")
            .alert("Info", isPresented: $showingInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(infoMessage)
            }
        }
    }
}

private extension SettingsTabView {
    func wipeHistory() {
        let store = MatchHistoryService()
        do {
            try store.wipeAll()
            infoMessage = "Local match history wiped."
            showingInfoAlert = true
        } catch {
            infoMessage = "Failed to wipe data: \(error.localizedDescription)"
            showingInfoAlert = true
        }
    }

    func seedDemoHistory() {
        let store = MatchHistoryService()
        let samples: [(String, String, Int, Int)] = [
            ("Leeds United", "Newcastle United", 2, 1),
            ("Arsenal", "Chelsea", 1, 1),
            ("Barcelona", "Real Madrid", 3, 2),
            ("Bayern", "Dortmund", 0, 0),
            ("Inter", "Milan", 4, 3)
        ]
        var saved = 0
        for s in samples {
            let m = Match(homeTeam: s.0, awayTeam: s.1)
            var final = m
            final.homeScore = s.2
            final.awayScore = s.3
            let snapshot = CompletedMatch(match: final, events: [])
            do { try store.save(snapshot); saved += 1 } catch { }
        }
        infoMessage = "Seeded \(saved) demo matches."
        showingInfoAlert = true
    }
}

#Preview { SettingsTabView() }
