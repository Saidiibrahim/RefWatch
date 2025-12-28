//
//  InMemoryScheduleStore.swift
//  RefWatchiOS
//
//  Simple in-memory fallback that satisfies ScheduleStoring when SwiftData is unavailable.
//

import Foundation
import Combine
import OSLog
import RefWatchCore

@MainActor
protocol ScheduleStoring {
    func loadAll() -> [ScheduledMatch]
    func save(_ item: ScheduledMatch) throws
    func delete(id: UUID) throws
    func wipeAll() throws
    var changesPublisher: AnyPublisher<[ScheduledMatch], Never> { get }
    func refreshFromRemote() async throws
}

@MainActor
final class InMemoryScheduleStore: ScheduleStoring {
    private var items: [ScheduledMatch]
    private let subject: CurrentValueSubject<[ScheduledMatch], Never>

    init(initial: [ScheduledMatch] = []) {
        self.items = initial
        self.subject = CurrentValueSubject(initial.sorted { $0.kickoff < $1.kickoff })
    }

    func loadAll() -> [ScheduledMatch] {
        items.sorted { $0.kickoff < $1.kickoff }
    }

    func save(_ item: ScheduledMatch) throws {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        publish()
    }

    func delete(id: UUID) throws {
        items.removeAll { $0.id == id }
        publish()
    }

    func wipeAll() throws {
        items.removeAll()
        publish()
    }

    var changesPublisher: AnyPublisher<[ScheduledMatch], Never> {
        subject.eraseToAnyPublisher()
    }

    func refreshFromRemote() async throws { }

    private func publish() {
        subject.send(loadAll())
    }
}
