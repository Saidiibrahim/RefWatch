//
//  MatchEventRecord.swift
//  RefWatch Watch App
//
//  Description: Comprehensive model for tracking detailed match events with timestamps and context
//

import Foundation

/// Detailed match event record with timestamp and full context
struct MatchEventRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let actualTime: Date // Wall-clock time when event occurred
    let matchTime: String // Time when event occurred (e.g., "23:45")
    let period: Int // Which half/period (1, 2, 3, 4 for extra time)
    let eventType: MatchEventType
    let team: TeamSide? // Optional for general match events
    let details: EventDetails
    
    init(
        matchTime: String,
        period: Int,
        eventType: MatchEventType,
        team: TeamSide? = nil,
        details: EventDetails
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.actualTime = Date()
        self.matchTime = matchTime
        self.period = period
        self.eventType = eventType
        self.team = team
        self.details = details
    }
}

/// Event type with associated data
enum MatchEventType: Codable {
    case goal(GoalDetails)
    case card(CardDetails)
    case substitution(SubstitutionDetails)
    case kickOff
    case periodStart(Int)
    case halfTime
    case periodEnd(Int)
    case matchEnd
    case penaltiesStart
    case penaltyAttempt(PenaltyAttemptDetails)
    case penaltiesEnd
    
    var displayName: String {
        switch self {
        case .goal: return "Goal"
        case .card(let details): return details.cardType == .yellow ? "Yellow Card" : "Red Card"
        case .substitution: return "Substitution"
        case .kickOff: return "Kick Off"
        case .periodStart(let period): return "Period \(period) Start"
        case .halfTime: return "Half Time"
        case .periodEnd(let period): return "Period \(period) End"
        case .matchEnd: return "Match End"
        case .penaltiesStart: return "Penalties Start"
        case .penaltyAttempt(let details):
            return details.result == .scored ? "Penalty Scored" : "Penalty Missed"
        case .penaltiesEnd: return "Penalties End"
        }
    }
}

/// Team side enumeration
enum TeamSide: String, Codable, CaseIterable {
    case home = "Home"
    case away = "Away"
}

/// Event details union type
enum EventDetails: Codable {
    case goal(GoalDetails)
    case card(CardDetails)
    case substitution(SubstitutionDetails)
    case general // For events like kick off, period changes
    case penalty(PenaltyAttemptDetails) // For individual penalty attempts
}

/// Goal event details
struct GoalDetails: Codable {
    let goalType: GoalType
    let playerNumber: Int?
    let playerName: String?
    
    enum GoalType: String, Codable {
        case regular = "Goal"
        case ownGoal = "Own Goal"
        case penalty = "Penalty"
        case freeKick = "Free Kick"
    }
}

/// Card event details
struct CardDetails: Codable {
    let cardType: CardType
    let recipientType: CardRecipientType
    let playerNumber: Int?
    let playerName: String?
    let officialRole: TeamOfficialRole?
    let reason: String
    
    enum CardType: String, Codable {
        case yellow = "Yellow"
        case red = "Red"
    }
}

/// Substitution event details
struct SubstitutionDetails: Codable {
    let playerOut: Int?
    let playerIn: Int?
    let playerOutName: String?
    let playerInName: String?
}

/// Penalty attempt event details
struct PenaltyAttemptDetails: Codable, Equatable {
    enum Result: String, Codable, CaseIterable {
        case scored
        case missed
    }
    let result: Result
    let playerNumber: Int?
    let round: Int
}

// CardRecipientType and TeamOfficialRole are defined in their respective model files

// MARK: - Display Extensions
extension MatchEventRecord {
    /// Formatted description for display in match logs
    var displayDescription: String {
        switch eventType {
        case .goal(let goalDetails):
            let goalTypeText = goalDetails.goalType.rawValue
            if let playerNum = goalDetails.playerNumber {
                return "\(goalTypeText) - #\(playerNum)"
            }
            return goalTypeText
            
        case .card(let cardDetails):
            let cardText = "\(cardDetails.cardType.rawValue) Card"
            if cardDetails.recipientType == .player, let playerNum = cardDetails.playerNumber {
                return "\(cardText) - #\(playerNum) (\(cardDetails.reason))"
            } else if cardDetails.recipientType == .teamOfficial, let role = cardDetails.officialRole {
                return "\(cardText) - \(role.rawValue) (\(cardDetails.reason))"
            }
            return "\(cardText) - \(cardDetails.reason)"
            
        case .substitution(let subDetails):
            if let playerOut = subDetails.playerOut, let playerIn = subDetails.playerIn {
                return "Substitution - #\(playerOut) → #\(playerIn)"
            }
            return "Substitution"
            
        case .penaltyAttempt(let details):
            let base = details.result == .scored ? "Penalty Scored" : "Penalty Missed"
            if let num = details.playerNumber {
                return "\(base) - R\(details.round) #\(num)"
            }
            return "\(base) - R\(details.round)"
        default:
            return eventType.displayName
        }
    }
    
    /// Team display name (optional for general events)
    var teamDisplayName: String? {
        team?.rawValue
    }
    
    /// Period display name
    var periodDisplayName: String {
        switch period {
        case 1: return "1st Half"
        case 2: return "2nd Half"
        case 3: return "Extra Time 1"
        case 4: return "Extra Time 2"
        case 5: return "Penalties"
        default: return "Period \(period)"
        }
    }
    
    /// Formatted actual time for display in logs
    var formattedActualTime: String {
        DateFormatter.watchShortTime.string(from: actualTime)
    }
}
