//
//  MatchesTabView.swift
//  RefWatchiOS
//
//  Hub for iOS match flow: start a match and browse history.
//

import SwiftUI
import RefWatchCore

struct MatchesTabView: View {
    @EnvironmentObject private var router: AppRouter
    let matchViewModel: MatchViewModel
    @State private var path: [Route] = []
    enum Route: Hashable { case setup, timer, historyList }
    @State private var recent: [CompletedMatch] = []

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

                // Today (in-progress)
                if matchViewModel.isMatchInProgress, let m = matchViewModel.currentMatch {
                    Section("Today") {
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

                // Past (recent history)
                Section("Past") {
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
            .onAppear { recent = matchViewModel.loadRecentCompletedMatches(limit: 5) }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .setup:
                    MatchSetupView(matchViewModel: matchViewModel) { _ in
                        path.append(.timer)
                    }
                case .timer:
                    MatchTimerView(matchViewModel: matchViewModel)
                case .historyList:
                    MatchHistoryView(matchViewModel: matchViewModel)
                }
            }
        }
    }
}
#Preview {
    MatchesTabView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
        .environmentObject(AppRouter.preview())
}
 
// No additional helpers.

private extension MatchesTabView {
    static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}
