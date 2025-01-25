// Defines all possible match events that can occur during a game
import Foundation

enum MatchEvent: String {
    // Cards
    case yellow = "Yellow Card"
    case red = "Red Card"
    
    // Goals
    case goal = "Goal"
    case ownGoal = "Own Goal"
    case penaltyGoal = "Penalty Goal"
    case freeKickGoal = "Free Kick Goal"
    
    // Other Events
    case substitution = "Substitution"
    case injury = "Injury"
    case timeout = "Timeout"
}