import Foundation

/// Ordered incident groupings for records-confirmation UIs.
public enum MatchRecordsSectionKind: String, CaseIterable, Equatable {
  case goals = "Goals"
  case cards = "Cards"
  case substitutions = "Substitutions"

  /// User-facing section title.
  public var title: String {
    self.rawValue
  }
}

/// A team-scoped slice of completed-match incidents for records confirmation.
public struct MatchRecordsSection: Equatable {
  public let kind: MatchRecordsSectionKind
  public let events: [MatchEventRecord]

  public init(kind: MatchRecordsSectionKind, events: [MatchEventRecord]) {
    self.kind = kind
    self.events = events
  }
}

public extension CompletedMatch {
  /// Returns the team incidents shown in records confirmation, preserving the
  /// original event order except that yellow cards lead red cards.
  func matchRecordsSections(for team: TeamSide) -> [MatchRecordsSection] {
    let teamEvents = self.events.filter { $0.team == team }
    let goals = teamEvents.filter(\.isGoalRecord)
    let cards = teamEvents.yellowCards + teamEvents.redCards
    let substitutions = teamEvents.filter(\.isSubstitutionRecord)

    return [
      MatchRecordsSection(kind: .goals, events: goals),
      MatchRecordsSection(kind: .cards, events: cards),
      MatchRecordsSection(kind: .substitutions, events: substitutions),
    ]
    .filter { $0.events.isEmpty == false }
  }
}

private extension Array where Element == MatchEventRecord {
  var yellowCards: [MatchEventRecord] {
    self.filter {
      guard case let .card(details) = $0.eventType else { return false }
      return details.cardType == .yellow
    }
  }

  var redCards: [MatchEventRecord] {
    self.filter {
      guard case let .card(details) = $0.eventType else { return false }
      return details.cardType == .red
    }
  }
}

private extension MatchEventRecord {
  var isGoalRecord: Bool {
    if case .goal = self.eventType {
      return true
    }
    return false
  }

  var isSubstitutionRecord: Bool {
    if case .substitution = self.eventType {
      return true
    }
    return false
  }
}
