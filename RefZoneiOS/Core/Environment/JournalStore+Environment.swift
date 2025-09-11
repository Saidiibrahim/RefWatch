//
//  JournalStore+Environment.swift
//  RefWatchiOS
//
//  Environment bridge for injecting JournalEntryStoring.
//

import SwiftUI
import RefWatchCore

private struct JournalStoreKey: EnvironmentKey {
    static let defaultValue: JournalEntryStoring = InMemoryJournalStore()
}

extension EnvironmentValues {
    var journalStore: JournalEntryStoring {
        get { self[JournalStoreKey.self] }
        set { self[JournalStoreKey.self] = newValue }
    }
}

