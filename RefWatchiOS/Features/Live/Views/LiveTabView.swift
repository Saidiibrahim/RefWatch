//
//  LiveTabView.swift
//  RefWatchiOS
//
//  Placeholder live mirror of current match
//

import SwiftUI

struct LiveTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: LiveSessionModel

    var body: some View {
        NavigationStack {
            Group {
                if session.isActive {
                    liveMirror
                } else {
                    emptyState
                }
            }
            .navigationTitle("Live")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { session.isActive ? session.end() : session.simulateStart(home: session.homeTeam, away: session.awayTeam) }
                    } label: { Text(session.isActive ? "End" : "Simulate") }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17, *) {
            ContentUnavailableView(
                "No Active Match",
                systemImage: "timer",
                description: Text("Start a match on your Apple Watch to mirror it here.")
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "timer").font(.largeTitle).foregroundStyle(.secondary)
                Text("No Active Match").font(.title3).bold()
                Text("Start a match on your Apple Watch to mirror it here.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private var liveMirror: some View {
        VStack(spacing: 16) {
            // Header: period + timers (static placeholders now)
            HStack {
                VStack(alignment: .leading) {
                    Text(session.periodLabel).font(.headline)
                    Text("Match \(session.matchTime) • Remaining \(session.periodTimeRemaining) • +\(session.stoppage)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            // Score strip
            HStack {
                teamScore(session.homeTeam, session.score.home)
                Spacer()
                Text("\(session.score.home) - \(session.score.away)").font(.title.bold())
                Spacer()
                teamScore(session.awayTeam, session.score.away)
            }
            .padding(.horizontal)

            // Event feed (static examples)
            List(session.events) { row in
                HStack(spacing: 12) {
                    Image(systemName: row.icon).foregroundStyle(row.color)
                    VStack(alignment: .leading) {
                        Text(row.title).font(.body)
                        Text(row.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(row.time).font(.caption.monospaced())
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func teamScore(_ name: String, _ score: Int) -> some View {
        VStack(spacing: 4) {
            Text(name).font(.subheadline.bold())
            Text("\(score)").font(.title2.bold())
        }
    }

    // Events now provided by LiveSessionModel
}

#Preview {
    LiveTabView()
        .environmentObject(AppRouter())
        .environmentObject(LiveSessionModel())
}

