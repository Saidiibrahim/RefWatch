import SwiftUI

struct CardReasonSelectionView: View {
    let cardType: CardDetails.CardType
    let isTeamOfficial: Bool
    let onSelect: (String) -> Void
    
    var body: some View {
        List {
            if isTeamOfficial {
                let filteredReasons = TeamOfficialCardReason.allCases.filter { reason in
                    switch cardType {
                    case .yellow:
                        return String(describing: reason).hasPrefix("YT")
                    case .red:
                        return String(describing: reason).hasPrefix("RT")
                    }
                }
                
                ForEach(filteredReasons, id: \.self) { reason in
                    Button(action: { onSelect(reason.rawValue) }) {
                        Text(reason.rawValue)
                            .foregroundColor(.primary)
                    }
                }
                
                if filteredReasons.isEmpty {
                    Text("No reasons available")
                        .foregroundColor(.secondary)
                }
            } else {
                if cardType == .yellow {
                    ForEach(YellowCardReason.allCases, id: \.self) { reason in
                        Button(action: { onSelect(reason.rawValue) }) {
                            Text("\(reason.rawValue)")
                                .foregroundColor(.primary)
                        }
                    }
                } else {
                    ForEach(RedCardReason.allCases, id: \.self) { reason in
                        Button(action: { onSelect(reason.rawValue) }) {
                            Text("\(reason.rawValue)")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle(cardType == .yellow ? "Yellow Card Reason" : "Red Card Reason")
        .listStyle(.plain)
        .onAppear {
            print("DEBUG: CardReasonSelectionView appeared")
            print("DEBUG: isTeamOfficial: \(isTeamOfficial)")
            print("DEBUG: cardType: \(cardType)")
            if isTeamOfficial {
                let filtered = TeamOfficialCardReason.allCases.filter { reason in
                    switch cardType {
                    case .yellow:
                        return String(describing: reason).hasPrefix("YT")
                    case .red:
                        return String(describing: reason).hasPrefix("RT")
                    }
                }
                print("DEBUG: Filtered team official reasons: \(filtered.map { $0.rawValue })")
            }
        }
    }
}
