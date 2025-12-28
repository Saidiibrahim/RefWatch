//
//  MatchesTabView.swift
//  RefWatchiOS
//
//  Hub for iOS match flow: start a match and browse history.
//

import SwiftUI
import Combine
import OSLog
import RefWatchCore

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
    @State private var lastNeedingJournal: CompletedMatch? = nil
    @State private var showingAddUpcoming = false
    @State private var deleteError: String? = nil

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isSignedIn {
                    signedInContent
                } else {
                    SignedOutFeaturePlaceholder(
                        description: "Sign in with your Supabase account to start matches, review history, and manage schedules on iPhone."
                    )
                }
            }
            .navigationTitle("Matches")
            .toolbar {
                if isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { path.append(.historyList) } label: { Label("History", systemImage: "clock") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAddUpcoming = true } label: { Label("Add Upcoming", systemImage: "calendar.badge.plus") }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { isSignedIn && showingAddUpcoming },
                set: { showingAddUpcoming = $0 }
            )) {
                if isSignedIn {
                    UpcomingMatchEditorView(scheduleStore: scheduleStore, teamStore: teamStore) {
                        refreshSchedule()
                    }
                } else {
                    SignedOutFeaturePlaceholder(
                        description: "Sign in to create or edit scheduled matches."
                    )
                }
            }
            .onChange(of: matchViewModel.matchCompleted) { _, completed in
                guard completed, isSignedIn else { return }
                refreshRecentAndPrompt()
            }
            .onReceive(NotificationCenter.default.publisher(for: .matchHistoryDidChange).receive(on: RunLoop.main)) { _ in
                guard isSignedIn else { return }
                refreshRecentAndPrompt()
            }
            .onReceive(NotificationCenter.default.publisher(for: .journalDidChange).receive(on: RunLoop.main)) { _ in
                guard isSignedIn else { return }
                refreshRecentAndPrompt()
            }
            .onReceive(scheduleStore.changesPublisher.receive(on: RunLoop.main)) { items in
                guard isSignedIn else { return }
                handleScheduleUpdate(items)
            }
            .onAppear {
                guard isSignedIn else {
                    path = []
                    showingAddUpcoming = false
                    return
                }
                // Trigger manual sync when view appears to ensure remote matches are loaded
                if let syncController = matchSyncController {
                    _ = syncController.requestManualSync()
                }
                refreshRecentAndPrompt()
                refreshSchedule()
            }
            .onChange(of: isSignedIn) { _, signedIn in
                if signedIn == false {
                    path = []
                    showingAddUpcoming = false
                    recent = []
                    today = []
                    upcoming = []
                    lastNeedingJournal = nil
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .setup:
                    MatchSetupView(
                        matchViewModel: matchViewModel,
                        teamStore: teamStore,
                        competitionStore: competitionStore,
                        venueStore: venueStore
                    ) { _ in
                        path = [.timer]
                    }
                case .timer:
                    MatchTimerView(matchViewModel: matchViewModel)
                case .historyList:
                    MatchHistoryView(matchViewModel: matchViewModel, historyStore: historyStore, matchSyncController: matchSyncController)
                case .scheduleSetup(let sched):
                    MatchSetupView(
                        matchViewModel: matchViewModel,
                        teamStore: teamStore,
                        competitionStore: competitionStore,
                        venueStore: venueStore,
                        onStarted: { _ in path = [.timer] },
                        scheduledMatch: sched
                    )
                }
            }
            .alert("Unable to Delete", isPresented: Binding(
                get: { deleteError != nil },
                set: { if $0 == false { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "An error occurred while deleting the scheduled match.")
            }
        }
    }

    private var isSignedIn: Bool { authController.isSignedIn }

    @ViewBuilder
    private var signedInContent: some View {
        List {
            Section {
                NavigationLink(value: Route.setup) {
                    Label("Start Match", systemImage: "play.circle.fill")
                        .font(.headline)
                }
            }

            if matchViewModel.isMatchInProgress, let m = matchViewModel.currentMatch {
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

            if !today.isEmpty {
                Section("Today") {
                    ForEach(today) { item in
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
                if upcoming.isEmpty {
                    ContentUnavailableView(
                        "No Upcoming Matches",
                        systemImage: "calendar",
                        description: Text("Add or sync scheduled matches.")
                    )
                } else {
                    ForEach(upcoming) { item in
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
                if recent.isEmpty {
                    ContentUnavailableView(
                        "No Past Matches",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finish a match to see it here.")
                    )
                } else {
                    ForEach(recent) { item in
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
        venueStore: InMemoryVenueLibraryStore()
    )
    .environmentObject(AppRouter.preview())
}
#endif
 
// No additional helpers.

private extension MatchesTabView {
    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func formatRelative(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return formatTime(date) }
        if calendar.isDateInTomorrow(date) { return "Tomorrow, \(formatTime(date))" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, h:mm a"
        return formatter.string(from: date)
    }

    func refreshRecentAndPrompt() {
        Task { await refreshRecentAndPromptAsync() }
    }

    @MainActor
    private func refreshRecentAndPromptAsync() async {
        recent = matchViewModel.loadRecentCompletedMatches(limit: 5)
        if let latest = matchViewModel.loadRecentCompletedMatches(limit: 1).first {
            let latestJournal = try? await journalStore.loadLatest(for: latest.id)
            lastNeedingJournal = latestJournal == nil ? latest : nil
        } else {
            lastNeedingJournal = nil
        }
    }

    func refreshSchedule() {
        handleScheduleUpdate(scheduleStore.loadAll())
    }

    func handleScheduleUpdate(_ matches: [ScheduledMatch]) {
        let result = Self.partitionSchedules(matches, now: Date(), calendar: Calendar.current)
        today = result.today
        upcoming = result.upcoming
    }

    func deleteScheduledMatch(id: UUID) {
        do {
            try scheduleStore.delete(id: id)
            AppLog.schedule.info("Deleted scheduled match: \(id.uuidString, privacy: .public)")
        } catch {
            AppLog.schedule.error("Failed to delete scheduled match: \(error.localizedDescription, privacy: .public)")
            deleteError = error.localizedDescription
        }
    }
}

extension MatchesTabView {
    static func partitionSchedules(
        _ matches: [ScheduledMatch],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (today: [ScheduledMatch], upcoming: [ScheduledMatch]) {
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
