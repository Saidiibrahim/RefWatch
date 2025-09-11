// TimerFaceModel.swift
// Contracts for swappable timer faces in watchOS

import Foundation
import RefWatchCore

// MARK: - Timer Face Model Contracts

/// Read-only state that a timer face may render.
public protocol TimerFaceModelState: AnyObject {
    // Match time labels
    var matchTime: String { get }
    var periodTime: String { get }
    var periodTimeRemaining: String { get }
    var halfTimeElapsed: String { get }

    // Stoppage
    var isInStoppage: Bool { get }
    var formattedStoppageTime: String { get }

    // Flags
    var isPaused: Bool { get }
    var isHalfTime: Bool { get }
    var waitingForHalfTimeStart: Bool { get }
    var isMatchInProgress: Bool { get }
    var currentPeriod: Int { get }
}

/// Minimal actions a face is allowed to trigger.
public protocol TimerFaceModelActions: AnyObject {
    func pauseMatch()
    func resumeMatch()
    func startHalfTimeManually()
}

/// Convenience composition for faces.
public typealias TimerFaceModel = TimerFaceModelState & TimerFaceModelActions
