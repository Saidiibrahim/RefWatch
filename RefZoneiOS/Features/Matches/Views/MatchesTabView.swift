//
//  MatchesTabView.swift
//  RefWatchiOS
//
//  Hub for iOS match flow: start a match and browse history.
//

import SwiftUI
import Combine
import RefWatchCore

struct MatchesTabView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.journalStore) private var journalStore
    let matchViewModel: MatchViewModel
    let historyStore: MatchHistoryStoring
    @State private var path: [Route] = []
    enum Route: Hashable { case setup, timer, historyList, scheduleSetup(ScheduledMatch) }
    @State private var recent: [CompletedMatch] = []
    @State private var today: [ScheduledMatch] = []
    @State private var upcoming: [ScheduledMatch] = []
    private let scheduleStore = ScheduleService()
    @State private var lastNeedingJournal: CompletedMatch? = nil

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // Primary action
                Section {
                    NavigationLink(value: Route.setup) {
                        Label("Start Match", systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                }

                // Live (in-progress)
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

                // Today (scheduled)
                if !today.isEmpty {
                    Section("Today") {
                        ForEach(today) { item in
                            NavigationLink(value: Route.scheduleSetup(item)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.homeTeam) vs \(item.awayTeam)").font(.headline)
                                    Text(Self.formatTime(item.kickoff)).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Upcoming (scheduled)
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
                        }
                    }
                }

                // Past (recent history)
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
            .navigationTitle("Matches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.historyList) } label: { Label("History", systemImage: "clock") }
                }
            }
            .onAppear {
                refreshRecentAndPrompt()
                let all = scheduleStore.loadAll()
                let now = Date()
                let cal = Calendar.current
                today = all.filter { cal.isDate($0.kickoff, inSameDayAs: now) }
                upcoming = all.filter { $0.kickoff > cal.startOfDay(for: now).addingTimeInterval(24*60*60) }
                    .sorted(by: { $0.kickoff < $1.kickoff })
            }
            .onChange(of: matchViewModel.matchCompleted) { completed in
                if completed { refreshRecentAndPrompt() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .matchHistoryDidChange).receive(on: RunLoop.main)) { _ in
                refreshRecentAndPrompt()
            }
            .onReceive(NotificationCenter.default.publisher(for: .journalDidChange).receive(on: RunLoop.main)) { _ in
                refreshRecentAndPrompt()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .setup:
                    MatchSetupView(matchViewModel: matchViewModel) { _ in
                        // Replace the stack with the timer so finishing returns to hub
                        path = [.timer]
                    }
                case .timer:
                    MatchTimerView(matchViewModel: matchViewModel)
                case .historyList:
                    MatchHistoryView(matchViewModel: matchViewModel, historyStore: historyStore)
                case .scheduleSetup(let sched):
                    MatchSetupView(
                        matchViewModel: matchViewModel,
                        onStarted: { _ in path = [.timer] },
                        prefillTeams: (sched.homeTeam, sched.awayTeam)
                    )
                }
            }
        }
    }
}
#if DEBUG
#Preview {
    MatchesTabView(matchViewModel: MatchViewModel(haptics: NoopHaptics()), historyStore: MatchHistoryService())
        .environmentObject(AppRouter.preview())
}
#endif
 
// No additional helpers.

private extension MatchesTabView {
    static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    static func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    static func formatRelative(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return formatTime(date) }
        if cal.isDateInTomorrow(date) { return "Tomorrow, \(formatTime(date))" }
        let f = DateFormatter(); f.dateFormat = "EEEE, h:mm a"
        return f.string(from: date)
    }
    func refreshRecentAndPrompt() {
        recent = matchViewModel.loadRecentCompletedMatches(limit: 5)
        // Compute prompt candidate
        if let latest = matchViewModel.loadRecentCompletedMatches(limit: 1).first {
            let latestJournal = (try? journalStore.loadLatest(for: latest.id)) ?? nil
            lastNeedingJournal = latestJournal == nil ? latest : nil
        } else {
            lastNeedingJournal = nil
        }
    }
}
