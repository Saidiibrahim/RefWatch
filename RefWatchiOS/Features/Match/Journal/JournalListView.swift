//
//  JournalListView.swift
//  RefWatchiOS
//

import Combine
import RefWatchCore
import SwiftUI

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
            Text("\(self.snapshot.match.homeTeam) vs \(self.snapshot.match.awayTeam)")
              .font(.headline)
            Text(Self.format(self.snapshot.completedAt)).font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Text("\(self.snapshot.match.homeScore) - \(self.snapshot.match.awayScore)")
            .font(.headline)
        }
      }

      Section("Entries") {
        if self.entries.isEmpty {
          ContentUnavailableView(
            "No Entries",
            systemImage: "square.and.pencil",
            description: Text("Add your self-assessment for this match."))
        } else {
          ForEach(self.entries) { entry in
            NavigationLink {
              JournalEditorView(matchId: self.snapshot.id, existing: entry) { self.load() }
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
            Task { await self.deleteEntries(at: offsets) }
          }
        }
      }
    }
    .navigationTitle("Self‑Assessment")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(action: { self.showEditor = true }, label: { Image(systemName: "plus") })
      }
    }
    .onAppear { self.load() }
    .onReceive(
      NotificationCenter.default.publisher(for: .journalDidChange)
        .receive(on: RunLoop.main))
    { _ in
      self.load()
    }
    .sheet(isPresented: self.$showEditor) {
      NavigationStack {
        JournalEditorView(matchId: self.snapshot.id) { self.load() }
      }
      .presentationDetents([.medium, .large])
    }
    .alert("Error", isPresented: self.$showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(self.errorMessage)
    }
  }

  private static func format(_ date: Date) -> String {
    let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
    return f.string(from: date)
  }

  private func load() {
    Task { await self.reloadEntries() }
  }

  @MainActor
  private func reloadEntries() async {
    do {
      self.entries = try await self.store.loadEntries(for: self.snapshot.id)
    } catch {
      self.show(error)
    }
  }

  @MainActor
  private func deleteEntries(at offsets: IndexSet) async {
    do {
      for idx in offsets {
        try await self.store.delete(id: self.entries[idx].id)
      }
      await self.reloadEntries()
    } catch {
      self.show(error)
    }
  }

  @MainActor
  private func show(_ error: Error) {
    self.errorMessage = error.localizedDescription
    self.showError = true
  }
}

#Preview {
  let match = Match(homeTeam: "Home", awayTeam: "Away")
  let snapshot = CompletedMatch(match: match, events: [])
  return NavigationStack { JournalListView(snapshot: snapshot) }
}
