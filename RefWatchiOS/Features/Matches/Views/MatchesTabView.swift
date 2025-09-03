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

    @State private var errorMessage: String?

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
                            router.openLive(home: home, away: away, session: session)
                        },
                        onSendToWatch: { home, away, when in
                            let c = ConnectivityClient.shared
                            guard c.isSupported, c.isPaired, c.isWatchAppInstalled, c.isReachable else {
                                errorMessage = "Apple Watch is not reachable. Check pairing and connectivity."
                                return
                            }
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
        .overlay(alignment: .top) {
            if let banner = connectivityBannerText {
                Text(banner)
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
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
    @State private var validationMessage: String?
    var onCreate: (Fixture) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    TextField("Home Team", text: $home)
                        .onChange(of: home) { _ in validate() }
                    TextField("Away Team", text: $away)
                        .onChange(of: away) { _ in validate() }
                }
                Section("Details") {
                    TextField("When", text: $when)
                        .onChange(of: when) { _ in validate() }
                    TextField("Venue", text: $venue)
                        .onChange(of: venue) { _ in validate() }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Validation error: \(validationMessage)")
                    }
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
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        let ok = validate()
        return ok
    }

    @discardableResult
    private func validate() -> Bool {
        func validTeam(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
            return CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-&'.")).isSuperset(of: CharacterSet(charactersIn: trimmed))
        }
        func validText(_ s: String, max: Int = 60) -> Bool {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return !t.isEmpty && t.count <= max
        }

        if !validTeam(home) { validationMessage = "Enter a valid Home team (max 40 chars)."; return false }
        if !validTeam(away) { validationMessage = "Enter a valid Away team (max 40 chars)."; return false }
        if !validText(when) { validationMessage = "Enter a valid date/time description."; return false }
        if !validText(venue, max: 50) { validationMessage = "Enter a valid venue (max 50 chars)."; return false }

        validationMessage = nil
        return true
    }
}

#Preview {
    MatchesTabView()
        .environmentObject(AppRouter.preview())
        .environmentObject(LiveSessionModel.preview(active: false))
}

// MARK: - Connectivity banner helper
private extension MatchesTabView {
    var connectivityBannerText: String? {
        let c = ConnectivityClient.shared
        guard c.isSupported else { return "WatchConnectivity not supported on this device" }
        guard c.isPaired else { return "Apple Watch not paired" }
        guard c.isWatchAppInstalled else { return "Watch app not installed" }
        return c.isReachable ? nil : "Apple Watch not reachable"
    }
}
