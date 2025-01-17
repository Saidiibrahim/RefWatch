import SwiftUI

struct CardRecipientSelectionView: View {
    let team: TeamDetailsView.TeamType
    let cardType: MatchEvent
    let onSelectPlayer: () -> Void
    let onSelectOfficial: () -> Void
    
    var body: some View {
        List {
            ForEach(CardRecipientType.allCases, id: \.self) { recipient in
                Button(action: {
                    switch recipient {
                    case .player:
                        onSelectPlayer()
                    case .teamOfficial:
                        onSelectOfficial()
                    }
                }) {
                    Text(recipient.rawValue)
                }
            }
        }
        .navigationTitle("Select Recipient")
    }
} 