import Foundation
import RefWatchCore

final class InMemoryHistoryStore: MatchHistoryStoring {
  private var matches: [CompletedMatch] = []

  func loadAll() throws -> [CompletedMatch] { matches }
  func save(_ match: CompletedMatch) throws { matches.append(match) }
  func delete(id: UUID) throws { matches.removeAll { $0.id == id } }
  func wipeAll() throws { matches.removeAll() }
}
