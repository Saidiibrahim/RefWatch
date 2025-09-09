import SwiftUI
import RefWatchCore

struct CardRecipientSelectionView: View {
    let team: TeamDetailsView.TeamType
    let cardType: CardDetails.CardType
    let onComplete: (CardRecipientType) -> Void // Simplified to only handle recipient selection
    
    var body: some View {
        List {
            ForEach(CardRecipientType.allCases, id: \.self) { recipient in
                Button(action: {
                    onComplete(recipient)
                }) {
                    Text(recipient.rawValue)
                }
            }
        }
        .navigationTitle("Select Recipient")
    }
} 
