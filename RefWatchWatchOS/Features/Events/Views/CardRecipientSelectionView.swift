//
//  CardRecipientSelectionView.swift
//  RefWatchWatchOS
//
//  Description: View for selecting card recipient type
//  Rule Applied: Code Structure - abstracted selection list to reusable component
//

import SwiftUI
import RefWatchCore

struct CardRecipientSelectionView: View {
    let team: TeamDetailsView.TeamType
    let cardType: CardDetails.CardType
    let onComplete: (CardRecipientType) -> Void
    
    private var accentColor: Color {
        cardType == .yellow ? .yellow : .red
    }

    var body: some View {
        // Use the new reusable SelectionListView component
        SelectionListView<CardRecipientType>(
            title: "Select Recipient",
            accentColor: accentColor
        ) { recipient in
            onComplete(recipient)
        }
    }
} 
