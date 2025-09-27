//
//  UpcomingMatchEditorView.swift
//  RefZoneiOS
//
//  Create or edit a scheduled match with optional library team selection.
//

import SwiftUI
import OSLog

struct UpcomingMatchEditorView: View {
    let scheduleStore: ScheduleStoring
    let teamStore: TeamLibraryStoring
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var homeName: String = ""
    @State private var awayName: String = ""
    @State private var kickoff: Date = Self.defaultKickoff()

    @State private var showingHomePicker = false
    @State private var showingAwayPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    HStack {
                        TextField("Home Team", text: $homeName)
                        Button { showingHomePicker = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                            .accessibilityLabel("Select Home Team from Library")
                    }
                    HStack {
                        TextField("Away Team", text: $awayName)
                        Button { showingAwayPicker = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                            .accessibilityLabel("Select Away Team from Library")
                    }
                }
                Section("Kickoff") {
                    DatePicker("Date & Time", selection: $kickoff, displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Button(action: save) { Label("Save", systemImage: "checkmark.circle.fill") }
                        .disabled(!isValid)
                }
            }
            .navigationTitle("Upcoming Match")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showingHomePicker) {
                NavigationStack { TeamsPickerView(teamStore: teamStore) { team in homeName = team.name } }
            }
            .sheet(isPresented: $showingAwayPicker) {
                NavigationStack { TeamsPickerView(teamStore: teamStore) { team in awayName = team.name } }
            }
        }
    }

    private var isValid: Bool {
        !homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !awayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let item = ScheduledMatch(
            homeTeam: homeName.trimmingCharacters(in: .whitespacesAndNewlines),
            awayTeam: awayName.trimmingCharacters(in: .whitespacesAndNewlines),
            kickoff: kickoff,
            needsRemoteSync: true
        )
        scheduleStore.save(item)
        AppLog.schedule.info("Saved scheduled match: \(item.homeTeam) vs \(item.awayTeam) @ \(item.kickoff.timeIntervalSince1970, privacy: .public)")
        onSaved?()
        dismiss()
    }

    private static func defaultKickoff() -> Date {
        let cal = Calendar.current
        let now = Date()
        // Default to next Saturday at 14:00 local time
        var comps = DateComponents()
        comps.weekday = 7 // Saturday
        comps.hour = 14
        comps.minute = 0
        let nextSat = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        return nextSat
    }
}

#Preview {
    UpcomingMatchEditorView(scheduleStore: ScheduleService(), teamStore: InMemoryTeamLibraryStore())
}
