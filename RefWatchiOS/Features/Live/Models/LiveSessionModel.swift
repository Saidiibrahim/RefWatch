//
//  LiveSessionModel.swift
//  RefWatchiOS
//
//  Holds lightweight state for the iOS Live mirror (placeholder)
//

import SwiftUI
import Combine

final class LiveSessionModel: ObservableObject {
    struct Score { var home: Int; var away: Int }
    struct Event: Identifiable, Hashable { let id = UUID(); let icon: String; let color: Color; let title: String; let subtitle: String; let time: String }

    @Published var isActive: Bool = false
    @Published var periodLabel: String = "Kick Off"
    @Published var matchTime: String = "00:00"
    @Published var periodTimeRemaining: String = "00:00"
    @Published var stoppage: String = "00:00"
    @Published var score: Score = .init(home: 0, away: 0)
    @Published var homeTeam: String = "HOM"
    @Published var awayTeam: String = "AWA"
    @Published var events: [Event] = []

    func simulateStart(home: String = "HOM", away: String = "AWA") {
        isActive = true
        periodLabel = "First Half"
        matchTime = "23:12"; periodTimeRemaining = "21:48"; stoppage = "01:20"
        score = .init(home: 1, away: 0)
        homeTeam = home; awayTeam = away
        events = [
            .init(icon: "soccerball", color: .green, title: "Goal — \(home) #9", subtitle: "Right-footed shot (open play)", time: "12:40"),
            .init(icon: "square.fill", color: .yellow, title: "Yellow Card — \(away) #6", subtitle: "Unsporting behaviour", time: "18:12"),
            .init(icon: "arrow.up.arrow.down", color: .blue, title: "Substitution — \(away)", subtitle: "#10 → #17", time: "22:01")
        ]
    }

    func end() {
        isActive = false
        periodLabel = "Kick Off"
        matchTime = "00:00"; periodTimeRemaining = "00:00"; stoppage = "00:00"
        score = .init(home: 0, away: 0)
        events.removeAll()
    }
}

