//
//  MatchesTabView.swift
//  RefWatchiOS
//
//  Placeholder list of fixtures/in-progress/recent matches
//

import SwiftUI

struct MatchesTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: LiveSessionModel
    @State private var segment: Segment = .upcoming
    @State private var fixtures: [Fixture] = [
        .init(id: UUID(), home: "Leeds United", away: "Newcastle", when: "Sat 15:00", venue: "Elland Road"),
        .init(id: UUID(), home: "Arsenal", away: "Brighton", when: "Sun 12:30", venue: "Emirates")
    ]
    @State private var showingCreate = false

    enum Segment: String, CaseIterable, Identifiable { case upcoming, inProgress, recent
        var id: String { rawValue }
        var title: String {
            switch self { case .upcoming: return "Upcoming"; case .inProgress: return "In‑Progress"; case .recent: return "Recent" }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Segment", selection: $segment) {
                    ForEach(Segment.allCases) { seg in
                        Text(seg.title).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                List(fixtures) { item in
                    NavigationLink(value: item) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.home) vs \(item.away)")
                                    .font(.headline)
                                Text("\(item.when) • \(item.venue)")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationDestination(for: Fixture.self) { fx in
                    FixtureDetailView(
                        fixture: fx,
                        onOpenLive: { home, away in
                            session.simulateStart(home: home, away: away)
                            router.selectedTab = 1
                        },
                        onSendToWatch: { home, away, when in
                            ConnectivityClient.shared.sendFixtureSummary(home: home, away: away, when: when)
                        }
                    )
                }
            }
            .navigationTitle("Matches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreate = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateFixtureView { new in fixtures.insert(new, at: 0) }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Models & Placeholder Detail
private struct Fixture: Identifiable, Hashable {
    let id: UUID
    let home: String
    let away: String
    let when: String
    let venue: String
}

private struct FixtureDetailView: View {
    let fixture: Fixture
    var onOpenLive: (String, String) -> Void
    var onSendToWatch: (String, String, String) -> Void
    var body: some View {
        List {
            Section("Fixture") {
                LabeledContent("Teams", value: "\(fixture.home) vs \(fixture.away)")
                LabeledContent("When", value: fixture.when)
                LabeledContent("Venue", value: fixture.venue)
            }
            Section("Actions") {
                Button { onSendToWatch(fixture.home, fixture.away, fixture.when) } label: { Label("Send to Watch", systemImage: "applewatch") }
                Button { onOpenLive(fixture.home, fixture.away) } label: { Label("Open Live Mirror", systemImage: "play.circle") }
            }
        }
        .navigationTitle("Fixture")
    }
}

// MARK: - Create Fixture (placeholder)
private struct CreateFixtureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var home: String = "Home"
    @State private var away: String = "Away"
    @State private var when: String = "Today 19:30"
    @State private var venue: String = "Venue"
    var onCreate: (Fixture) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    TextField("Home Team", text: $home)
                    TextField("Away Team", text: $away)
                }
                Section("Details") {
                    TextField("When", text: $when)
                    TextField("Venue", text: $venue)
                }
            }
            .navigationTitle("New Fixture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(.init(id: UUID(), home: home, away: away, when: when, venue: venue))
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MatchesTabView()
        .environmentObject(AppRouter())
        .environmentObject(LiveSessionModel())
}

