//
//  PlayerNumberInputView.swift
//  RefZoneWatchOS
//
//  Description: View for entering player number using a numeric keypad interface
//  Rule Applied: Code Structure - abstracted keypad to reusable component
//

import SwiftUI
import RefWatchCore

struct PlayerNumberInputView: View {
    let team: TeamDetailsView.TeamType
    let goalType: GoalDetails.GoalType?
    let cardType: CardDetails.CardType?
    let context: String? // New parameter for contextual placeholder
    let onComplete: (Int) -> Void
    
    @State private var numberString = ""
    
    var body: some View {
        VStack(spacing: 12) {
            // Add title based on context
            // Text(goalType != nil ? "Goal Scorer" : "Player Number")
            //     .font(.system(size: 16, weight: .medium))
            //     .padding(.top)
            
            // Use the new reusable NumericKeypad component with contextual placeholder
            NumericKeypad(
                numberString: $numberString,
                maxDigits: 2,
                placeholder: context ?? "0",
                placeholderColor: .gray
            ) { number in
                onComplete(number)
            }
        }
        // .navigationBarTitleDisplayMode(.inline)
    }
}
