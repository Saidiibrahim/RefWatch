//
//  ScoreStripView.swift
//  RefWatchiOS
//
//  Lightweight iOS score display component inspired by the watch ScoreDisplayView.
//

import SwiftUI

struct ScoreStripView: View {
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int

    var body: some View {
        HStack {
            VStack(spacing: 4) {
                Text(homeTeam).font(.subheadline).bold()
                Text("\(homeScore)").font(.title2).bold()
            }
            Spacer()
            VStack(spacing: 4) {
                Text(awayTeam).font(.subheadline).bold()
                Text("\(awayScore)").font(.title2).bold()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

#Preview {
    ScoreStripView(homeTeam: "HOM", awayTeam: "AWA", homeScore: 1, awayScore: 0)
}
