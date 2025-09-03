//
//  TeamModels.swift
//  RefWatchCore
//
//  Models related to team management including roles and personnel
//

import Foundation

public enum TeamOfficialRole: String, Codable, CaseIterable {
    case manager = "Manager"
    case assistantManager = "Assistant Manager"
    case coach = "Coach"
    case physio = "Physio"
    case doctor = "Doctor"
}

