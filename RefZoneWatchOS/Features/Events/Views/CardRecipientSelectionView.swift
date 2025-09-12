//
//  CardRecipientSelectionView.swift
//  RefZoneWatchOS
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
    
    var body: some View {
        // Use the new reusable SelectionListView component
        SelectionListView<CardRecipientType>(
            title: "Select Recipient"
        ) { recipient in
            onComplete(recipient)
        }
    }
} 
