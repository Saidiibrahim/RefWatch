//
//  CardModels.swift
//  RefWatchCore
//
//  Models for card-related functionality
//

import Foundation

public enum CardRecipientType: String, Codable, CaseIterable {
    case player = "Player"
    case teamOfficial = "Team Official"
}

public enum YellowCardReason: String, CaseIterable {
    case Y1 = "Unsporting Behavior"
    case Y2 = "Dissent"
    case Y3 = "Persistent Infringement"
    case Y4 = "Delaying Restart"
    case Y5 = "Distance Violation"
    case Y6 = "Entering Without Permission"
}

public enum RedCardReason: String, CaseIterable {
    case R1 = "Serious Foul Play"
    case R2 = "Violent Conduct"
    case R3 = "Spitting/Biting"
    case R4 = "DOGSO - Handball"
    case R5 = "DOGSO - Foul"
    case R6 = "Offensive Language"
    case R7 = "Second Yellow"
}

public enum TeamOfficialCardReason: String, CaseIterable {
    // Yellow card reasons
    case YT1 = "Persistent Protests"
    case YT2 = "Delaying Restart"
    case YT3 = "Entering Field"
    case YT4 = "Leaving Technical Area"
    
    // Red card reasons
    case RT1 = "Violent Conduct"
    case RT2 = "Throwing Objects"
    case RT3 = "Offensive Language"
    case RT4 = "Entering Field Aggressively"
}

