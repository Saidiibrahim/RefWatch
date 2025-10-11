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
