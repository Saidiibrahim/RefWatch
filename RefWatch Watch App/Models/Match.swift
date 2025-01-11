//
//  Match.swift
//  RefereeAssistant
//
//  Description: Data model representing a match in progress.
//

import Foundation

struct Match {
    var startTime: Date?
    var duration: TimeInterval  // In seconds
    
    init() {
        self.startTime = nil
        self.duration = 0
    }
}

