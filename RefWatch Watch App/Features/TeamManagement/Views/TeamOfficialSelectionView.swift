import SwiftUI

struct TeamOfficialSelectionView: View {
    let team: TeamDetailsView.TeamType
    let onSelect: (TeamOfficialRole) -> Void
    
    var body: some View {
        List {
            ForEach(TeamOfficialRole.allCases, id: \.self) { role in
                Button(action: { onSelect(role) }) {
                    Text(role.rawValue)
                }
            }
        }
        .navigationTitle("Select Official")
    }
} 