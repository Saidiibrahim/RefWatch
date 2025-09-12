//
//  JournalListView.swift
//  RefZoneiOS
//

import SwiftUI
import RefWatchCore
import Combine

struct JournalListView: View {
    let snapshot: CompletedMatch

    @Environment(\.journalStore) private var store
    @State private var entries: [JournalEntry] = []
    @State private var showEditor = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(snapshot.match.homeTeam) vs \(snapshot.match.awayTeam)")
                            .font(.headline)
                        Text(Self.format(snapshot.completedAt)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(snapshot.match.homeScore) - \(snapshot.match.awayScore)")
                        .font(.headline)
                }
            }

            Section("Entries") {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "square.and.pencil",
                        description: Text("Add your self-assessment for this match.")
                    )
                } else {
                    ForEach(entries) { entry in
                        NavigationLink {
                            JournalEditorView(matchId: snapshot.id, existing: entry) { load() }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if let rating = entry.rating { Text("⭐️ \(rating)/5").font(.subheadline) }
                                    Spacer()
                                    Text(Self.format(entry.updatedAt)).font(.caption).foregroundStyle(.secondary)
                                }
                                if let txt = entry.overall, !txt.isEmpty {
                                    Text(txt).lineLimit(2)
                                } else if let txt = entry.wentWell, !txt.isEmpty {
                                    Text(txt).lineLimit(2)
                                } else if let txt = entry.toImprove, !txt.isEmpty {
                                    Text(txt).lineLimit(2)
                                } else {
                                    Text("(No text)").foregroundStyle(.secondary).font(.caption)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        for idx in offsets { do { try store.delete(id: entries[idx].id) } catch { show(error) } }
                        load()
                    }
                }
            }
        }
        .navigationTitle("Self‑Assessment")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: { showEditor = true }) { Image(systemName: "plus") } } }
        .onAppear { load() }
        .onReceive(NotificationCenter.default.publisher(for: .journalDidChange).receive(on: RunLoop.main)) { _ in load() }
        .sheet(isPresented: $showEditor) {
            NavigationStack { JournalEditorView(matchId: snapshot.id) { load() } }
                .presentationDetents([.medium, .large])
        }
        .alert("Error", isPresented: $showError) { Button("OK", role: .cancel) {} } message: { Text(errorMessage) }
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
        return f.string(from: date)
    }
    private func load() {
        entries = (try? store.loadEntries(for: snapshot.id)) ?? []
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

#Preview {
    let match = Match(homeTeam: "Home", awayTeam: "Away")
    let snapshot = CompletedMatch(match: match, events: [])
    return NavigationStack { JournalListView(snapshot: snapshot) }
}
