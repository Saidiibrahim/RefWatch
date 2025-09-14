//
//  TimerManager.swift
//  RefWatchCore
//
//  Focused service responsible for match timing, stoppage tracking,
//  and half-time elapsed updates. Extracted for SRP and testability.
//

import Foundation
import Observation
#if os(watchOS)
import WatchKit
#endif

public final class TimerManager: @unchecked Sendable { // @Observable in app; observation not needed for package
    // MARK: - Snapshot
    public struct Snapshot: Equatable {
        public var matchTime: String
        public var periodTime: String
        public var periodTimeRemaining: String
        public var formattedStoppageTime: String
        public var isInStoppage: Bool

        public static func zero() -> Snapshot {
            Snapshot(
                matchTime: "00:00",
                periodTime: "00:00",
                periodTimeRemaining: "00:00",
                formattedStoppageTime: "00:00",
                isInStoppage: false
            )
        }
    }

    // MARK: - Internal State
    private var periodTimer: Timer?
    private var stoppageTimer: Timer?
    private var halftimeTimer: Timer?

    private var periodStartTime: Date?
    private var halfTimeStartTime: Date?
    private var stoppageStartTime: Date?

    private var stoppageAccumulated: TimeInterval = 0
    private var lastSnapshot: Snapshot = .zero()
    private var didFireHalftimeHaptic: Bool = false

    // Persist current context so pause/resume can compute correctly
    private var activeMatch: Match?
    private var activePeriod: Int = 1

    // Closures supplied by VM/UI
    private var onTick: ((Snapshot) -> Void)?
    private var onPeriodEnd: (() -> Void)?

    public init() {}

    // MARK: - Public API

    /// Returns the per-period label (MM:SS) derived from the match configuration and period.
    public func configureInitialPeriodLabel(match: Match, currentPeriod: Int) -> String {
        let per = perPeriodDurationSeconds(for: match, currentPeriod: currentPeriod)
        return formatMMSS(per)
    }

    /// Starts ticking for the current period. Calls `onTick` every second with updated snapshot.
    public func startPeriod(
        match: Match,
        currentPeriod: Int,
        onTick: @escaping (Snapshot) -> Void,
        onPeriodEnd: @escaping () -> Void
    ) {
        // Save context
        self.activeMatch = match
        self.activePeriod = currentPeriod
        self.onTick = onTick
        self.onPeriodEnd = onPeriodEnd

        // Reset and start
        stopPeriodTimer()
        periodStartTime = Date()
        startPeriodTimer()
    }

    /// Pauses period timer and starts stoppage updates.
    public func pause(onTick: @escaping (Snapshot) -> Void) {
        self.onTick = onTick

        stopPeriodTimer()
        if stoppageStartTime == nil {
            stoppageStartTime = Date()
        }
        // Mark stoppage active and start displaying it
        lastSnapshot.isInStoppage = true
        // While paused, keep the elapsed match clock updating. Compute an
        // immediate matchTime snapshot so UI reflects a coherent state.
        if let match = activeMatch, let start = periodStartTime {
            let now = Date()
            let periodElapsed = now.timeIntervalSince(start)
            // Sum durations of all prior periods
            var priorDurations: TimeInterval = 0
            if activePeriod > 1 {
                for i in 1..<(activePeriod) {
                    priorDurations += perPeriodDurationSeconds(for: match, currentPeriod: i)
                }
            }
            let totalMatchElapsed = priorDurations + periodElapsed
            lastSnapshot.matchTime = formatMMSS(totalMatchElapsed)
        }
        startStoppageTimer()
        // Emit immediate tick with latest state
        DispatchQueue.main.async { onTick(self.lastSnapshot) }
    }

    /// Resumes period timer and accumulates stoppage.
    public func resume(onTick: @escaping (Snapshot) -> Void) {
        self.onTick = onTick

        // Accumulate stoppage and stop its timer
        if let start = stoppageStartTime {
            stoppageAccumulated += Date().timeIntervalSince(start)
        }
        stoppageStartTime = nil
        stopStoppageTimer()

        // Update snapshot to reflect final stoppage so far
        lastSnapshot.isInStoppage = false
        lastSnapshot.formattedStoppageTime = formatMMSS(stoppageAccumulated)
        DispatchQueue.main.async { onTick(self.lastSnapshot) }

        // Resume the period ticking (do not change periodStartTime)
        startPeriodTimer()
    }

    // MARK: - Stoppage While Running
    /// Begins stoppage display/accumulation while keeping the period timer running.
    /// Does not alter `periodStartTime` or stop the period timer.
    public func beginStoppageWhileRunning(onTick: @escaping (Snapshot) -> Void) {
        self.onTick = onTick
        if stoppageStartTime == nil { stoppageStartTime = Date() }
        lastSnapshot.isInStoppage = true
        startStoppageTimer()
        DispatchQueue.main.async { onTick(self.lastSnapshot) }
    }

    /// Ends stoppage display/accumulation while keeping the period timer running.
    public func endStoppageWhileRunning(onTick: @escaping (Snapshot) -> Void) {
        self.onTick = onTick
        if let start = stoppageStartTime {
            stoppageAccumulated += Date().timeIntervalSince(start)
        }
        stoppageStartTime = nil
        stopStoppageTimer()
        lastSnapshot.isInStoppage = false
        lastSnapshot.formattedStoppageTime = formatMMSS(stoppageAccumulated)
        DispatchQueue.main.async { onTick(self.lastSnapshot) }
    }

    /// Clears stoppage for a fresh period and resets stoppage display.
    public func resetForNewPeriod() {
        stoppageAccumulated = 0
        stoppageStartTime = nil
        lastSnapshot.formattedStoppageTime = "00:00"
        lastSnapshot.isInStoppage = false
        stopStoppageTimer()
    }

    /// Starts half-time elapsed updates (counts up). Fires haptic when configured length reached.
    public func startHalfTime(match: Match, onTick: @escaping (String) -> Void) {
        stopHalftimeTimer()
        self.halfTimeStartTime = Date()
        self.didFireHalftimeHaptic = false

        halftimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.halfTimeStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            let label = self.formatMMSS(elapsed)
            DispatchQueue.main.async {
                onTick(label)
            }
            if elapsed >= match.halfTimeLength && !self.didFireHalftimeHaptic {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.notification)
                #endif
                self.didFireHalftimeHaptic = true
            }
        }
        if let t = halftimeTimer { RunLoop.current.add(t, forMode: .common) }
    }

    /// Stops half-time updates.
    public func stopHalfTime() {
        stopHalftimeTimer()
        halfTimeStartTime = nil
        didFireHalftimeHaptic = false
    }

    /// Stops all timers and clears callbacks. Safe to call multiple times.
    public func stopAll() {
        stopPeriodTimer()
        stopStoppageTimer()
        stopHalftimeTimer()
        didFireHalftimeHaptic = false
        onTick = nil
        onPeriodEnd = nil
        activeMatch = nil
    }

    deinit {
        stopAll()
    }

    // MARK: - Private Helpers

    private func startPeriodTimer() {
        // Prevent multiple period timers; maintain exactly one active per period
        guard periodTimer == nil else { return }
        periodTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.handlePeriodTick()
        }
        if let t = periodTimer { RunLoop.current.add(t, forMode: .common) }
    }

    private func handlePeriodTick() {
        guard let match = activeMatch, let start = periodStartTime else { return }

        let now = Date()
        let periodElapsed = now.timeIntervalSince(start)
        let perDuration = perPeriodDurationSeconds(for: match, currentPeriod: activePeriod)

        let remaining = max(0, perDuration - periodElapsed)
        // Sum durations of all prior periods to get the correct accumulated match time
        var priorDurations: TimeInterval = 0
        if activePeriod > 1 {
            for i in 1..<(activePeriod) {
                priorDurations += perPeriodDurationSeconds(for: match, currentPeriod: i)
            }
        }
        let totalMatchElapsed = priorDurations + periodElapsed

        var snapshot = lastSnapshot
        snapshot.periodTime = formatMMSS(periodElapsed)
        snapshot.periodTimeRemaining = formatMMSS(remaining)
        snapshot.matchTime = formatMMSS(totalMatchElapsed)

        // If currently in stoppage, update the displayed value
        if snapshot.isInStoppage, let stopStart = stoppageStartTime {
            let currentStoppage = stoppageAccumulated + now.timeIntervalSince(stopStart)
            snapshot.formattedStoppageTime = formatMMSS(currentStoppage)
        }

        lastSnapshot = snapshot
        if let onTick = onTick {
            DispatchQueue.main.async { onTick(snapshot) }
        }

        // End of period
        if periodElapsed >= perDuration {
            stopPeriodTimer()
            if let onPeriodEnd = onPeriodEnd {
                DispatchQueue.main.async { onPeriodEnd() }
            }
        }
    }

    private func startStoppageTimer() {
        stopStoppageTimer()
        stoppageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            if let start = self.stoppageStartTime {
                let current = self.stoppageAccumulated + now.timeIntervalSince(start)
                self.lastSnapshot.formattedStoppageTime = self.formatMMSS(current)
                // If the period timer is paused, keep matchTime ticking by computing it here.
                if self.periodTimer == nil, let match = self.activeMatch, let pStart = self.periodStartTime {
                    let periodElapsed = now.timeIntervalSince(pStart)
                    var priorDurations: TimeInterval = 0
                    if self.activePeriod > 1 {
                        for i in 1..<(self.activePeriod) {
                            priorDurations += self.perPeriodDurationSeconds(for: match, currentPeriod: i)
                        }
                    }
                    let totalMatchElapsed = priorDurations + periodElapsed
                    self.lastSnapshot.matchTime = self.formatMMSS(totalMatchElapsed)
                }
                if let onTick = self.onTick {
                    DispatchQueue.main.async { onTick(self.lastSnapshot) }
                }
            }
        }
        if let t = stoppageTimer { RunLoop.current.add(t, forMode: .common) }
    }

    private func stopPeriodTimer() {
        periodTimer?.invalidate()
        periodTimer = nil
    }

    private func stopStoppageTimer() {
        stoppageTimer?.invalidate()
        stoppageTimer = nil
    }

    private func stopHalftimeTimer() {
        halftimeTimer?.invalidate()
        halftimeTimer = nil
    }

    private func perPeriodDurationSeconds(for match: Match, currentPeriod: Int) -> TimeInterval {
        // Regular time periods
        let regularPeriods = max(1, match.numberOfPeriods)
        if currentPeriod <= regularPeriods {
            let per = match.duration / TimeInterval(regularPeriods)
            return max(0, per)
        }

        // Extra time halves (support up to 2 ET periods beyond regulation)
        let etIndex = currentPeriod - regularPeriods
        if etIndex == 1 || etIndex == 2 {
            return max(0, match.extraTimeHalfLength)
        }

        // Fallback: treat as zero-duration (e.g., penalties don't use period timer)
        return 0
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let mm = total / 60
        let ss = total % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}
