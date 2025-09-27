//
//  MatchEventRecord.swift
//  RefWatchCore
//
//  Comprehensive model for tracking detailed match events with timestamps and context
//

import Foundation

/// Detailed match event record with timestamp and full context
public struct MatchEventRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let actualTime: Date // Wall-clock time when event occurred
    public let matchTime: String // Time when event occurred (e.g., "23:45")
    public let period: Int // Which half/period (1, 2, 3, 4 for extra time)
    public let eventType: MatchEventType
    public let team: TeamSide? // Optional for general match events
    public let details: EventDetails
    
    public init(
        matchTime: String,
        period: Int,
        eventType: MatchEventType,
        team: TeamSide? = nil,
        details: EventDetails
    ) {
        self.id = UUID()
        let now = Date()
        self.timestamp = now
        self.actualTime = now
        self.matchTime = matchTime
        self.period = period
        self.eventType = eventType
        self.team = team
        self.details = details
    }

    /// Allows callers (e.g. Supabase sync) to hydrate events with their
    /// original identity and timestamps instead of generating new ones.
    public init(
        id: UUID,
        timestamp: Date,
        actualTime: Date,
        matchTime: String,
        period: Int,
        eventType: MatchEventType,
        team: TeamSide?,
        details: EventDetails
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actualTime = actualTime
        self.matchTime = matchTime
        self.period = period
        self.eventType = eventType
        self.team = team
        self.details = details
    }
}

/// Event type with associated data
public enum MatchEventType: Codable, Equatable {
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
    
    public var displayName: String {
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
public enum TeamSide: String, Codable, CaseIterable, Equatable {
    case home = "Home"
    case away = "Away"
}

/// Event details union type
public enum EventDetails: Codable, Equatable {
    case goal(GoalDetails)
    case card(CardDetails)
    case substitution(SubstitutionDetails)
    case general // For events like kick off, period changes
    case penalty(PenaltyAttemptDetails) // For individual penalty attempts
}

/// Goal event details
public struct GoalDetails: Codable, Equatable {
    public let goalType: GoalType
    public let playerNumber: Int?
    public let playerName: String?
    
    public init(goalType: GoalType, playerNumber: Int?, playerName: String?) {
        self.goalType = goalType
        self.playerNumber = playerNumber
        self.playerName = playerName
    }
    
    public enum GoalType: String, Codable, Equatable {
        case regular = "Goal"
        case ownGoal = "Own Goal"
        case penalty = "Penalty"
        case freeKick = "Free Kick"
    }
}

/// Card event details
public struct CardDetails: Codable, Equatable {
    public let cardType: CardType
    public let recipientType: CardRecipientType
    public let playerNumber: Int?
    public let playerName: String?
    public let officialRole: TeamOfficialRole?
    public let reason: String
    
    public init(cardType: CardType, recipientType: CardRecipientType, playerNumber: Int?, playerName: String?, officialRole: TeamOfficialRole?, reason: String) {
        self.cardType = cardType
        self.recipientType = recipientType
        self.playerNumber = playerNumber
        self.playerName = playerName
        self.officialRole = officialRole
        self.reason = reason
    }
    
    public enum CardType: String, Codable, Equatable {
        case yellow = "Yellow"
        case red = "Red"
    }
}

/// Substitution event details
public struct SubstitutionDetails: Codable, Equatable {
    public let playerOut: Int?
    public let playerIn: Int?
    public let playerOutName: String?
    public let playerInName: String?
    
    public init(playerOut: Int?, playerIn: Int?, playerOutName: String?, playerInName: String?) {
        self.playerOut = playerOut
        self.playerIn = playerIn
        self.playerOutName = playerOutName
        self.playerInName = playerInName
    }
}

/// Penalty attempt event details
public struct PenaltyAttemptDetails: Codable, Equatable {
    public enum Result: String, Codable, CaseIterable {
        case scored
        case missed
    }
    public let result: Result
    public let playerNumber: Int?
    public let round: Int
    
    public init(result: Result, playerNumber: Int?, round: Int) {
        self.result = result
        self.playerNumber = playerNumber
        self.round = round
    }
}

// CardRecipientType and TeamOfficialRole are defined in their respective model files

// MARK: - Display Extensions
public extension MatchEventRecord {
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
