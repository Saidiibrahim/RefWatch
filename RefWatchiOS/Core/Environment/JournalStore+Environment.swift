//
//  JournalStore+Environment.swift
//  RefWatchiOS
//
//  Environment bridge for injecting JournalEntryStoring.
//

import SwiftUI
import RefWatchCore

private struct JournalStoreKey: EnvironmentKey {
    @MainActor static var defaultValue: JournalEntryStoring { InMemoryJournalStore() }
}

extension EnvironmentValues {
    var journalStore: JournalEntryStoring {
        get { self[JournalStoreKey.self] }
        set { self[JournalStoreKey.self] = newValue }
    }
}

// Noop fallback no longer needed as we rely on @MainActor default builder.
