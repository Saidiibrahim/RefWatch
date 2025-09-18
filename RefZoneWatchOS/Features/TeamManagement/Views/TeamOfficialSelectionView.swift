import SwiftUI
import RefWatchCore

struct TeamOfficialSelectionView: View {
  let team: TeamDetailsView.TeamType
  let onSelect: (TeamOfficialRole) -> Void

  var body: some View {
    SelectionListView(
      title: "Select Official",
      options: TeamOfficialRole.allCases,
      formatter: { $0.rawValue },
      onSelect: onSelect
    )
  }
}
