// New file: PlayerNumberInputView.swift
// Description: View for entering player number using a numeric keypad interface

import SwiftUI

struct PlayerNumberInputView: View {
    let team: TeamDetailsView.TeamType
    let goalType: GoalTypeSelectionView.GoalType?
    let cardType: MatchEvent?
    let onComplete: (Int) -> Void
    
    @State private var numberString = ""
    
    // Updated grid layout - removed bottom row
    let keypadLayout = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", ""]  // Empty strings for spacing
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Add title based on context
            Text(goalType != nil ? "Goal Scorer" : "Player Number")
                .font(.headline)
                .padding(.top)
            
            // Number display
            Text(numberString.isEmpty ? "0" : numberString)
                .font(.system(size: 40, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            
            // Keypad grid
            VStack(spacing: 12) {
                ForEach(keypadLayout, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { key in
                            if !key.isEmpty {
                                KeypadButton(
                                    key: key,
                                    action: { handleKeyPress(key) }
                                )
                            } else {
                                // Empty spacer for layout
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") {
                    submitNumber()
                }
                .disabled(numberString.isEmpty)
            }
        }
    }
    
    private func handleKeyPress(_ key: String) {
        if numberString.count < 2 {
            numberString += key
        }
    }
    
    private func submitNumber() {
        if let number = Int(numberString), number > 0 {
            onComplete(number)
        }
    }
}

// Updated KeypadButton
private struct KeypadButton: View {
    let key: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 22))
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(22)
        }
    }
}