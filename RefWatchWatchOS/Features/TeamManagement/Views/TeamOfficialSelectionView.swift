import RefWatchCore
import SwiftUI

struct TeamOfficialSelectionResult: Equatable, Hashable {
  let officialName: String?
  let officialRole: TeamOfficialRole?
  let officialRoleLabel: String?
}

struct TeamOfficialSelectionOption: Identifiable, Equatable, Hashable {
  let participantId: UUID
  let displayName: String
  let roleLabel: String?
  let category: MatchSheetStaffCategory

  var id: UUID { self.participantId }

  init(participantId: UUID, displayName: String, roleLabel: String?, category: MatchSheetStaffCategory) {
    self.participantId = participantId
    self.displayName = displayName
    self.roleLabel = roleLabel
    self.category = category
  }

  init(official: MatchSelectableOfficial) {
    self.init(
      participantId: official.participantId,
      displayName: official.displayName,
      roleLabel: official.roleLabel,
      category: official.category)
  }

  var displayLabel: String {
    let trimmedRole = self.roleLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmedRole, trimmedRole.isEmpty == false {
      return "\(self.displayName) · \(trimmedRole)"
    }
    return self.displayName
  }

  var selection: TeamOfficialSelectionResult {
    TeamOfficialSelectionResult(
      officialName: self.displayName,
      officialRole: self.roleLabel.flatMap(TeamOfficialRole.init(rawValue:)),
      officialRoleLabel: self.roleLabel)
  }
}

struct TeamOfficialSelectionView: View {
  let title: String
  let savedOfficials: [TeamOfficialSelectionOption]
  let onSelect: (TeamOfficialSelectionResult) -> Void

  init(
    title: String = "Select Official",
    savedOfficials: [TeamOfficialSelectionOption] = [],
    onSelect: @escaping (TeamOfficialSelectionResult) -> Void)
  {
    self.title = title
    self.savedOfficials = savedOfficials
    self.onSelect = onSelect
  }

  var body: some View {
    SelectionListView(
      title: self.title,
      options: self.selectionRows,
      formatter: { $0.displayLabel },
      onSelect: { row in
        self.onSelect(row.selection)
      })
  }

  private var selectionRows: [SelectionRow] {
    let savedRows = self.savedOfficials.map(SelectionRow.saved)
    let genericRows = TeamOfficialRole.allCases.map(SelectionRow.generic)
    return savedRows + genericRows
  }
}

private enum SelectionRow: Hashable {
  case saved(TeamOfficialSelectionOption)
  case generic(TeamOfficialRole)

  var displayLabel: String {
    switch self {
    case let .saved(option):
      return option.displayLabel
    case let .generic(role):
      return "\(role.rawValue) (Generic)"
    }
  }

  var selection: TeamOfficialSelectionResult {
    switch self {
    case let .saved(option):
      return option.selection
    case let .generic(role):
      return TeamOfficialSelectionResult(
        officialName: nil,
        officialRole: role,
        officialRoleLabel: role.rawValue)
    }
  }
}
