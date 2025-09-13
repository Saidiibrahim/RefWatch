//
//  CompactTeamBox.swift
//  RefZoneWatchOS
//
//  Description: Compact team selection box component optimized for watch screen space
//

import SwiftUI

/// Compact team box component optimized for watch screen space
struct CompactTeamBox: View {
    let teamName: String
    let score: Int
    let isSelected: Bool
    let action: () -> Void
    let accessibilityIdentifier: String?
    
    init(
        teamName: String,
        score: Int,
        isSelected: Bool,
        action: @escaping () -> Void,
        accessibilityIdentifier: String? = nil
    ) {
        self.teamName = teamName
        self.score = score
        self.isSelected = isSelected
        self.action = action
        self.accessibilityIdentifier = accessibilityIdentifier
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(teamName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 65) // Reduced from 80pt for better fit
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.7))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier ?? "teamBox_\(teamName)")
    }
}

#Preview {
    HStack(spacing: 10) {
        CompactTeamBox(
            teamName: "HOM",
            score: 1,
            isSelected: true,
            action: { print("Home selected") },
            accessibilityIdentifier: "homeTeamButton"
        )
        
        CompactTeamBox(
            teamName: "AWA",
            score: 0,
            isSelected: false,
            action: { print("Away selected") },
            accessibilityIdentifier: "awayTeamButton"
        )
    }
    .padding()
}
