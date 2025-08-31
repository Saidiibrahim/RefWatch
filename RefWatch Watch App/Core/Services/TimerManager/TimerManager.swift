//
//  TimerManager.swift
//  RefWatch Watch App
//
//  Description: Focused service responsible for match timing, stoppage tracking,
//  and half-time elapsed updates. Extracted for SRP and testability.
//

import Foundation
import Observation
import WatchKit

@Observable
final class TimerManager {
    // MARK: - Snapshot
    struct Snapshot: Equatable {
        var matchTime: String
        var periodTime: String
        var periodTimeRemaining: String
        var formattedStoppageTime: String
        var isInStoppage: Bool

        static func zero() -> Snapshot {
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

    // Persist current context so pause/resume can compute correctly
    private var activeMatch: Match?
    private var activePeriod: Int = 1

    // Closures supplied by VM/UI
    private var onTick: ((Snapshot) -> Void)?
    private var onPeriodEnd: (() -> Void)?

    // MARK: - Public API

    /// Returns the per-period label (MM:SS) derived from the match configuration.
    func configureInitialPeriodLabel(match: Match, currentPeriod: Int) -> String {
        let per = perPeriodDurationSeconds(for: match)
        return formatMMSS(per)
    }

    /// Starts ticking for the current period. Calls `onTick` every second with updated snapshot.
    func startPeriod(
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
    func pause(onTick: @escaping (Snapshot) -> Void) {
        self.onTick = onTick

        stopPeriodTimer()
        if stoppageStartTime == nil {
            stoppageStartTime = Date()
        }
        // Mark stoppage active and start displaying it
        lastSnapshot.isInStoppage = true
        startStoppageTimer()
        // Emit immediate tick with latest state
        DispatchQueue.main.async { onTick(self.lastSnapshot) }
    }

    /// Resumes period timer and accumulates stoppage.
    func resume(onTick: @escaping (Snapshot) -> Void) {
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

    /// Clears stoppage for a fresh period and resets stoppage display.
    func resetForNewPeriod() {
        stoppageAccumulated = 0
        stoppageStartTime = nil
        lastSnapshot.formattedStoppageTime = "00:00"
        lastSnapshot.isInStoppage = false
        stopStoppageTimer()
    }

    /// Starts half-time elapsed updates (counts up). Fires haptic when configured length reached.
    func startHalfTime(match: Match, onTick: @escaping (String) -> Void) {
        stopHalftimeTimer()
        self.halfTimeStartTime = Date()

        halftimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.halfTimeStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            let label = self.formatMMSS(elapsed)
            DispatchQueue.main.async {
                onTick(label)
            }
            if elapsed >= match.halfTimeLength {
                // Haptic notification when halftime duration reached
                WKInterfaceDevice.current().play(.notification)
            }
        }
        if let t = halftimeTimer { RunLoop.current.add(t, forMode: .common) }
    }

    /// Stops half-time updates.
    func stopHalfTime() {
        stopHalftimeTimer()
        halfTimeStartTime = nil
    }

    /// Stops all timers and clears callbacks. Safe to call multiple times.
    func stopAll() {
        stopPeriodTimer()
        stopStoppageTimer()
        stopHalftimeTimer()
        onTick = nil
        onPeriodEnd = nil
        activeMatch = nil
    }

    deinit {
        stopAll()
    }

    // MARK: - Private Helpers

    private func startPeriodTimer() {
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
        let perDuration = perPeriodDurationSeconds(for: match)

        let remaining = max(0, perDuration - periodElapsed)
        let totalMatchElapsed = TimeInterval(max(0, activePeriod - 1)) * perDuration + periodElapsed

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

    private func perPeriodDurationSeconds(for match: Match) -> TimeInterval {
        let periods = max(1, match.numberOfPeriods)
        let per = match.duration / TimeInterval(periods)
        return max(0, per)
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let mm = total / 60
        let ss = total % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}
