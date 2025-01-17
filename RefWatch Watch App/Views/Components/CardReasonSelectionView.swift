import SwiftUI

struct CardReasonSelectionView: View {
    let cardType: MatchEvent
    let isTeamOfficial: Bool
    let onSelect: (String) -> Void
    
    var body: some View {
        List {
            if isTeamOfficial {
                ForEach(TeamOfficialCardReason.allCases, id: \.self) { reason in
                    if cardType == .yellow && reason.rawValue.hasPrefix("YT") ||
                       cardType == .red && reason.rawValue.hasPrefix("RT") {
                        Button(action: { onSelect(reason.rawValue) }) {
                            Text(reason.rawValue)
                        }
                    }
                }
            } else {
                if cardType == .yellow {
                    ForEach(YellowCardReason.allCases, id: \.self) { reason in
                        Button(action: { onSelect(reason.rawValue) }) {
                            Text("\(reason.rawValue) - \(reason)")
                        }
                    }
                } else {
                    ForEach(RedCardReason.allCases, id: \.self) { reason in
                        Button(action: { onSelect(reason.rawValue) }) {
                            Text("\(reason.rawValue) - \(reason)")
                        }
                    }
                }
            }
        }
        .navigationTitle(cardType == .yellow ? "Yellow Card Reason" : "Red Card Reason")
    }
} 