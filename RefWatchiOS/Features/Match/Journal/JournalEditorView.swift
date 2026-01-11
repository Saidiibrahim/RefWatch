//
//  JournalEditorView.swift
//  RefWatchiOS
//

import RefWatchCore
import SwiftUI

struct JournalEditorView: View {
  let matchId: UUID
  var existing: JournalEntry?
  var onSaved: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.journalStore) private var store

  @State private var rating: Int = 0
  @State private var overall: String = ""
  @State private var wentWell: String = ""
  @State private var toImprove: String = ""
  @State private var showError = false
  @State private var errorMessage = ""

  var body: some View {
    Form {
      Section("Rating") {
        Stepper(value: self.$rating, in: 0...5) {
          LabeledContent("Overall", value: self.rating == 0 ? "None" : "\(self.rating)/5")
        }
        Text("Optional star rating to summarize your performance.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section("Overall Reflection") {
        TextEditor(text: self.$overall)
          .frame(minHeight: 80)
      }

      Section("What Went Well") {
        TextEditor(text: self.$wentWell)
          .frame(minHeight: 80)
      }

      Section("What To Improve") {
        TextEditor(text: self.$toImprove)
          .frame(minHeight: 80)
      }
    }
    .navigationTitle(self.existing == nil ? "Add Assessment" : "Edit Assessment")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") { self.dismiss() }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Save") { self.save() }
          .bold()
      }
    }
    .onAppear { self.preload() }
    .alert("Error", isPresented: self.$showError) {
      Button("OK", role: .cancel) {}
    } message: { Text(self.errorMessage) }
  }

  private func preload() {
    guard let existing else { return }
    self.rating = existing.rating ?? 0
    self.overall = existing.overall ?? ""
    self.wentWell = existing.wentWell ?? ""
    self.toImprove = existing.toImprove ?? ""
  }

  private func save() {
    Task { @MainActor in
      do {
        if var entry = existing {
          entry.rating = self.rating == 0 ? nil : self.rating
          entry.overall = self.overall.isEmpty ? nil : self.overall
          entry.wentWell = self.wentWell.isEmpty ? nil : self.wentWell
          entry.toImprove = self.toImprove.isEmpty ? nil : self.toImprove
          entry.updatedAt = Date()
          try await self.store.upsert(entry)
        } else {
          _ = try await self.store.create(
            matchId: self.matchId,
            rating: self.rating == 0 ? nil : self.rating,
            overall: self.overall.isEmpty ? nil : self.overall,
            wentWell: self.wentWell.isEmpty ? nil : self.wentWell,
            toImprove: self.toImprove.isEmpty ? nil : self.toImprove)
        }
        self.onSaved?()
        self.dismiss()
      } catch {
        self.errorMessage = error.localizedDescription
        self.showError = true
      }
    }
  }
}

#Preview {
  NavigationStack {
    JournalEditorView(matchId: UUID())
  }
}
