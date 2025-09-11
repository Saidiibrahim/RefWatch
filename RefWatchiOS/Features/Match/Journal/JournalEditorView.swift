//
//  JournalEditorView.swift
//  RefWatchiOS
//

import SwiftUI
import RefWatchCore

struct JournalEditorView: View {
    let matchId: UUID
    var existing: JournalEntry? = nil
    var onSaved: (() -> Void)? = nil

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
                Stepper(value: $rating, in: 0...5) {
                    LabeledContent("Overall", value: rating == 0 ? "None" : "\(rating)/5")
                }
                Text("Optional star rating to summarize your performance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Overall Reflection") {
                TextEditor(text: $overall)
                    .frame(minHeight: 80)
            }

            Section("What Went Well") {
                TextEditor(text: $wentWell)
                    .frame(minHeight: 80)
            }

            Section("What To Improve") {
                TextEditor(text: $toImprove)
                    .frame(minHeight: 80)
            }
        }
        .navigationTitle(existing == nil ? "Add Assessment" : "Edit Assessment")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .bold()
            }
        }
        .onAppear { preload() }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage) }
    }

    private func preload() {
        guard let existing else { return }
        rating = existing.rating ?? 0
        overall = existing.overall ?? ""
        wentWell = existing.wentWell ?? ""
        toImprove = existing.toImprove ?? ""
    }

    private func save() {
        do {
            if var entry = existing {
                entry.rating = rating == 0 ? nil : rating
                entry.overall = overall.isEmpty ? nil : overall
                entry.wentWell = wentWell.isEmpty ? nil : wentWell
                entry.toImprove = toImprove.isEmpty ? nil : toImprove
                entry.updatedAt = Date()
                try store.upsert(entry)
            } else {
                _ = try store.create(
                    matchId: matchId,
                    rating: rating == 0 ? nil : rating,
                    overall: overall.isEmpty ? nil : overall,
                    wentWell: wentWell.isEmpty ? nil : wentWell,
                    toImprove: toImprove.isEmpty ? nil : toImprove
                )
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        JournalEditorView(matchId: UUID())
    }
}

