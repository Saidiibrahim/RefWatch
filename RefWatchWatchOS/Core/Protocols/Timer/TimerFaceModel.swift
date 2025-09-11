// TimerFaceModel.swift
// Contracts for swappable timer faces in watchOS

import Foundation
import RefWatchCore

// MARK: - Timer Face Model Contracts

/// Read-only state exposed to timer faces.
/// Notes:
/// - Faces are purely visual; they must not perform navigation or lifecycle routing.
/// - Values are derived from MatchViewModel/TimerManager; faces should not cache derived time.
/// - The host view guarantees a valid face selection. If a stored face value is unknown,
///   the host falls back to `.standard` to ensure a consistent experience.
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

/// Minimal actions a face is allowed to trigger. Faces should not orchestrate
/// period transitions beyond pause/resume/explicit half-time start.
public protocol TimerFaceModelActions: AnyObject {
    func pauseMatch()
    func resumeMatch()
    func startHalfTimeManually()
}

/// Convenience composition for faces.
public typealias TimerFaceModel = TimerFaceModelState & TimerFaceModelActions
