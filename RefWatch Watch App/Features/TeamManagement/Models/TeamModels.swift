// TeamModels.swift
// Description: Models related to team management including roles and personnel

import Foundation

enum TeamOfficialRole: String, CaseIterable {
    case manager = "Manager"
    case assistantManager = "Assistant Manager"
    case coach = "Coach"
    case physio = "Physio"
    case doctor = "Doctor"
} 