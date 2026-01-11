//
//  UpcomingMatchEditorView.swift
//  RefWatchiOS
//
//  Create or edit a scheduled match with optional library team selection.
//

import OSLog
import SwiftUI

struct UpcomingMatchEditorView: View {
  let scheduleStore: ScheduleStoring
  let teamStore: TeamLibraryStoring
  var onSaved: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var authController: SupabaseAuthController
  @State private var homeName: String = ""
  @State private var awayName: String = ""
  @State private var kickoff: Date = Self.defaultKickoff()

  @State private var showingHomePicker = false
  @State private var showingAwayPicker = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Group {
        if self.isSignedIn {
          self.formContent
        } else {
          SignedOutFeaturePlaceholder(
            description: "Sign in to create or edit scheduled matches.")
        }
      }
      .navigationTitle("Upcoming Match")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { self.dismiss() } }
      }
    }
  }

  private var isSignedIn: Bool { self.authController.isSignedIn }

  @ViewBuilder
  private var formContent: some View {
    Form {
      Section("Teams") {
        HStack {
          TextField("Home Team", text: self.$homeName)
          Button { self.showingHomePicker = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
            .accessibilityLabel("Select Home Team from Library")
        }
        HStack {
          TextField("Away Team", text: self.$awayName)
          Button { self.showingAwayPicker = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
            .accessibilityLabel("Select Away Team from Library")
        }
      }
      Section("Kickoff") {
        DatePicker("Date & Time", selection: self.$kickoff, displayedComponents: [.date, .hourAndMinute])
      }
      Section {
        Button(action: self.save) { Label("Save", systemImage: "checkmark.circle.fill") }
          .disabled(!self.isValid)
      }
    }
    .sheet(isPresented: self.$showingHomePicker) {
      NavigationStack { TeamsPickerView(teamStore: self.teamStore) { team in self.homeName = team.name } }
    }
    .sheet(isPresented: self.$showingAwayPicker) {
      NavigationStack { TeamsPickerView(teamStore: self.teamStore) { team in self.awayName = team.name } }
    }
    .alert("Unable to Save", isPresented: self.alertBinding) {
      Button("OK", role: .cancel) { self.errorMessage = nil }
    } message: {
      Text(self.errorMessage ?? "Sign in to save scheduled matches on your phone.")
    }
  }

  private var isValid: Bool {
    !self.homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !self.awayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var alertBinding: Binding<Bool> {
    Binding(
      get: { self.errorMessage != nil },
      set: { newValue in
        if newValue == false { self.errorMessage = nil }
      })
  }

  private func save() {
    let item = ScheduledMatch(
      homeTeam: homeName.trimmingCharacters(in: .whitespacesAndNewlines),
      awayTeam: self.awayName.trimmingCharacters(in: .whitespacesAndNewlines),
      kickoff: self.kickoff,
      needsRemoteSync: true,
      lastModifiedAt: Date())
    do {
      try self.scheduleStore.save(item)
      AppLog.schedule
        .info(
          "Saved scheduled match: \(item.homeTeam) vs \(item.awayTeam) @ \(item.kickoff.timeIntervalSince1970, privacy: .public)")
      self.onSaved?()
      self.dismiss()
    } catch {
      AppLog.schedule.error("Scheduled match save failed: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = error.localizedDescription
    }
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
  UpcomingMatchEditorView(scheduleStore: InMemoryScheduleStore(), teamStore: InMemoryTeamLibraryStore())
}
