//
//  MatchesTabView.swift
//  RefWatchiOS
//
//  Hub for iOS match flow: start a match and browse history.
//

import Combine
import OSLog
import RefWatchCore
import SwiftUI

struct MatchesTabView: View {
  @EnvironmentObject private var router: AppRouter
  @EnvironmentObject private var authController: SupabaseAuthController
  @Environment(\.journalStore) private var journalStore
  let matchViewModel: MatchViewModel
  let historyStore: MatchHistoryStoring
  let matchSyncController: MatchHistorySyncControlling?
  let scheduleStore: ScheduleStoring
  let teamStore: TeamLibraryStoring
  let competitionStore: CompetitionLibraryStoring
  let venueStore: VenueLibraryStoring
  @State private var path: [Route] = []
  enum Route: Hashable { case setup, timer, historyList, scheduleSetup(ScheduledMatch) }
  @State private var recent: [CompletedMatch] = []
  @State private var today: [ScheduledMatch] = []
  @State private var upcoming: [ScheduledMatch] = []
  @State private var lastNeedingJournal: CompletedMatch?
  @State private var showingAddUpcoming = false
  @State private var deleteError: String?

  var body: some View {
    NavigationStack(path: self.$path) {
      Group {
        if self.isSignedIn {
          self.signedInContent
        } else {
          SignedOutFeaturePlaceholder(
            description: "Sign in with your Supabase account to start matches, " +
              "review history, and manage schedules on iPhone.")
        }
      }
      .navigationTitle("Matches")
      .toolbar {
        if self.isSignedIn {
          ToolbarItem(placement: .topBarTrailing) {
            Button { self.path.append(.historyList) } label: { Label("History", systemImage: "clock") }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button { self.showingAddUpcoming = true } label: {
              Label("Add Upcoming", systemImage: "calendar.badge.plus")
            }
          }
        }
      }
      .sheet(isPresented: Binding(
        get: { self.isSignedIn && self.showingAddUpcoming },
        set: { self.showingAddUpcoming = $0 }))
      {
        if self.isSignedIn {
          UpcomingMatchEditorView(scheduleStore: self.scheduleStore, teamStore: self.teamStore) {
            refreshSchedule()
          }
        } else {
          SignedOutFeaturePlaceholder(
            description: "Sign in to create or edit scheduled matches.")
        }
      }
      .onChange(of: self.matchViewModel.matchCompleted) { _, completed in
        guard completed, self.isSignedIn else { return }
        refreshRecentAndPrompt()
      }
      .onReceive(NotificationCenter.default.publisher(for: .matchHistoryDidChange).receive(on: RunLoop.main)) { _ in
        guard self.isSignedIn else { return }
        refreshRecentAndPrompt()
      }
      .onReceive(NotificationCenter.default.publisher(for: .journalDidChange).receive(on: RunLoop.main)) { _ in
        guard self.isSignedIn else { return }
        refreshRecentAndPrompt()
      }
      .onReceive(self.scheduleStore.changesPublisher.receive(on: RunLoop.main)) { items in
        guard self.isSignedIn else { return }
        handleScheduleUpdate(items)
      }
      .onAppear {
        guard self.isSignedIn else {
          self.path = []
          self.showingAddUpcoming = false
          return
        }
        // Trigger manual sync when view appears to ensure remote matches are loaded
        if let syncController = matchSyncController {
          _ = syncController.requestManualSync()
        }
        refreshRecentAndPrompt()
        refreshSchedule()
      }
      .onChange(of: self.isSignedIn) { _, signedIn in
        if signedIn == false {
          self.path = []
          self.showingAddUpcoming = false
          self.recent = []
          self.today = []
          self.upcoming = []
          self.lastNeedingJournal = nil
        }
      }
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .setup:
          MatchSetupView(
            matchViewModel: self.matchViewModel,
            teamStore: self.teamStore,
            competitionStore: self.competitionStore,
            venueStore: self.venueStore)
          { _ in
            self.path = [.timer]
          }
        case .timer:
          MatchTimerView(matchViewModel: self.matchViewModel)
        case .historyList:
          MatchHistoryView(
            matchViewModel: self.matchViewModel,
            historyStore: self.historyStore,
            matchSyncController: self.matchSyncController)
        case let .scheduleSetup(sched):
          MatchSetupView(
            matchViewModel: self.matchViewModel,
            teamStore: self.teamStore,
            competitionStore: self.competitionStore,
            venueStore: self.venueStore,
            onStarted: { _ in self.path = [.timer] },
            scheduledMatch: sched)
        }
      }
      .alert("Unable to Delete", isPresented: Binding(
        get: { self.deleteError != nil },
        set: { if $0 == false { self.deleteError = nil } }
      )) {
        Button("OK", role: .cancel) { self.deleteError = nil }
      } message: {
        Text(self.deleteError ?? "An error occurred while deleting the scheduled match.")
      }
    }
  }

  private var isSignedIn: Bool { self.authController.isSignedIn }

  @ViewBuilder
  private var signedInContent: some View {
    List {
      Section {
        NavigationLink(value: Route.setup) {
          Label("Start Match", systemImage: "play.circle.fill")
            .font(.headline)
        }
      }

      if self.matchViewModel.isMatchInProgress, let m = matchViewModel.currentMatch {
        Section("Live") {
          NavigationLink(value: Route.timer) {
            VStack(alignment: .leading, spacing: 4) {
              Text("\(m.homeTeam) vs \(m.awayTeam)")
                .font(.headline)
              Text("In progress")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }
      }

      if !self.today.isEmpty {
        Section("Today") {
          ForEach(self.today) { item in
            NavigationLink(value: Route.scheduleSetup(item)) {
              VStack(alignment: .leading, spacing: 4) {
                Text("\(item.homeTeam) vs \(item.awayTeam)").font(.headline)
                Text(Self.formatTime(item.kickoff)).font(.subheadline).foregroundStyle(.secondary)
              }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) {
                deleteScheduledMatch(id: item.id)
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
          }
        }
      }

      Section("Upcoming") {
        if self.upcoming.isEmpty {
          ContentUnavailableView(
            "No Upcoming Matches",
            systemImage: "calendar",
            description: Text("Add or sync scheduled matches."))
        } else {
          ForEach(self.upcoming) { item in
            NavigationLink(value: Route.scheduleSetup(item)) {
              VStack(alignment: .leading, spacing: 4) {
                Text("\(item.homeTeam) vs \(item.awayTeam)").font(.headline)
                Text(Self.formatRelative(item.kickoff)).font(.subheadline).foregroundStyle(.secondary)
              }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) {
                deleteScheduledMatch(id: item.id)
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
          }
        }
      }

      Section("Past") {
        if let need = lastNeedingJournal {
          NavigationLink(destination: JournalEditorView(matchId: need.id, onSaved: { refreshRecentAndPrompt() })) {
            Label("Journal your last match", systemImage: "square.and.pencil")
          }
        }
        if self.recent.isEmpty {
          ContentUnavailableView(
            "No Past Matches",
            systemImage: "clock.arrow.circlepath",
            description: Text("Finish a match to see it here."))
        } else {
          ForEach(self.recent) { item in
            NavigationLink(destination: MatchHistoryDetailView(snapshot: item)) {
              VStack(alignment: .leading, spacing: 4) {
                Text("\(item.match.homeTeam) vs \(item.match.awayTeam)")
                  .font(.body)
                Text(Self.format(item.completedAt))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        NavigationLink(value: Route.historyList) { Text("See All History") }
      }
    }
  }
}

#if DEBUG
#Preview {
  MatchesTabView(
    matchViewModel: MatchViewModel(haptics: NoopHaptics()),
    historyStore: MatchHistoryService(),
    matchSyncController: nil,
    scheduleStore: InMemoryScheduleStore(),
    teamStore: InMemoryTeamLibraryStore(),
    competitionStore: InMemoryCompetitionLibraryStore(),
    venueStore: InMemoryVenueLibraryStore())
    .environmentObject(AppRouter.preview())
}
#endif

// No additional helpers.

extension MatchesTabView {
  fileprivate static func format(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  fileprivate static func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  fileprivate static func formatRelative(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return self.formatTime(date) }
    if calendar.isDateInTomorrow(date) { return "Tomorrow, \(self.formatTime(date))" }
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, h:mm a"
    return formatter.string(from: date)
  }

  private func refreshRecentAndPrompt() {
    Task { await self.refreshRecentAndPromptAsync() }
  }

  @MainActor
  private func refreshRecentAndPromptAsync() async {
    self.recent = self.matchViewModel.loadRecentCompletedMatches(limit: 5)
    if let latest = matchViewModel.loadRecentCompletedMatches(limit: 1).first {
      let latestJournal = try? await journalStore.loadLatest(for: latest.id)
      self.lastNeedingJournal = latestJournal == nil ? latest : nil
    } else {
      self.lastNeedingJournal = nil
    }
  }

  private func refreshSchedule() {
    self.handleScheduleUpdate(self.scheduleStore.loadAll())
  }

  private func handleScheduleUpdate(_ matches: [ScheduledMatch]) {
    let result = Self.partitionSchedules(matches, now: Date(), calendar: Calendar.current)
    self.today = result.today
    self.upcoming = result.upcoming
  }

  private func deleteScheduledMatch(id: UUID) {
    do {
      try self.scheduleStore.delete(id: id)
      AppLog.schedule.info("Deleted scheduled match: \(id.uuidString, privacy: .public)")
    } catch {
      AppLog.schedule.error("Failed to delete scheduled match: \(error.localizedDescription, privacy: .public)")
      self.deleteError = error.localizedDescription
    }
  }
}

extension MatchesTabView {
  static func partitionSchedules(
    _ matches: [ScheduledMatch],
    now: Date = Date(),
    calendar: Calendar = .current) -> (today: [ScheduledMatch], upcoming: [ScheduledMatch])
  {
    let startOfTomorrow = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
    let activeMatches = matches.filter { match in
      match.status != .completed && match.status != .canceled
    }

    let todayMatches = activeMatches
      .filter { calendar.isDate($0.kickoff, inSameDayAs: now) }
      .sorted { $0.kickoff < $1.kickoff }

    let upcomingMatches = activeMatches
      .filter { $0.kickoff > startOfTomorrow }
      .sorted { $0.kickoff < $1.kickoff }

    return (todayMatches, upcomingMatches)
  }
}
