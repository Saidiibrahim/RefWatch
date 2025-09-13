// ScoreDisplayView.swift
// Description: Component for displaying team names and scores in a horizontal layout

import SwiftUI

struct ScoreDisplayView: View {
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // Home team
            VStack {
                Text(homeTeam)
                    .font(.system(size: 14, weight: .medium))
                Text("\(homeScore)")
                    .font(.system(size: 24, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            
            // Away team
            VStack {
                Text(awayTeam)
                    .font(.system(size: 14, weight: .medium))
                Text("\(awayScore)")
                    .font(.system(size: 24, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
        }
        .padding(.vertical, 8)
    }
} 