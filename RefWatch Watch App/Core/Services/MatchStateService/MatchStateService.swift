// File: MatchStateService.swift
// New service to handle match state logic

import Foundation
import Observation

@Observable final class MatchStateService {
    private(set) var currentPeriod: Int = 1
    private(set) var isHalfTime: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var matchStatus: MatchStatus = .notStarted
    
    enum MatchStatus {
        case notStarted
        case inProgress
        case halfTime
        case finished
    }
    
    func startPeriod() {
        isPaused = false
        matchStatus = .inProgress
    }
    
    func endPeriod() {
        isPaused = true
        if currentPeriod == 1 {
            isHalfTime = true
            matchStatus = .halfTime
        } else {
            matchStatus = .finished
        }
    }
    
    func startNextPeriod() {
        guard isHalfTime else { return }
        currentPeriod += 1
        isHalfTime = false
        isPaused = false
        matchStatus = .inProgress
    }
    
    func togglePause() {
        isPaused.toggle()
    }
    
    var canStartNextPeriod: Bool {
        isHalfTime && currentPeriod == 1
    }
} 