//
//  TimerManager.swift
//  RefWatchCore
//
//  Focused service responsible for match timing, stoppage tracking,
//  and half-time elapsed updates. Extracted for SRP and testability.
//

import Foundation
import Observation

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

    public struct PersistenceState: Codable, Equatable {
        public var periodStartTime: Date?
        public var halfTimeStartTime: Date?
        public var stoppageStartTime: Date?
        public var stoppageAccumulated: TimeInterval
        public var isInStoppage: Bool
        public var didRequestHalftimeDurationCue: Bool

        public init(
            periodStartTime: Date? = nil,
            halfTimeStartTime: Date? = nil,
            stoppageStartTime: Date? = nil,
            stoppageAccumulated: TimeInterval = 0,
            isInStoppage: Bool = false,
            didRequestHalftimeDurationCue: Bool = false
        ) {
            self.periodStartTime = periodStartTime
            self.halfTimeStartTime = halfTimeStartTime
            self.stoppageStartTime = stoppageStartTime
            self.stoppageAccumulated = stoppageAccumulated
            self.isInStoppage = isInStoppage
            self.didRequestHalftimeDurationCue = didRequestHalftimeDurationCue
        }

        private enum CodingKeys: String, CodingKey {
            case periodStartTime
            case halfTimeStartTime
            case stoppageStartTime
            case stoppageAccumulated
            case isInStoppage
            case didRequestHalftimeDurationCue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.periodStartTime = try container.decodeIfPresent(Date.self, forKey: .periodStartTime)
            self.halfTimeStartTime = try container.decodeIfPresent(Date.self, forKey: .halfTimeStartTime)
            self.stoppageStartTime = try container.decodeIfPresent(Date.self, forKey: .stoppageStartTime)
            self.stoppageAccumulated = try container.decodeIfPresent(TimeInterval.self, forKey: .stoppageAccumulated) ?? 0
            self.isInStoppage = try container.decodeIfPresent(Bool.self, forKey: .isInStoppage) ?? false
            self.didRequestHalftimeDurationCue =
                try container.decodeIfPresent(Bool.self, forKey: .didRequestHalftimeDurationCue) ?? false
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
    private var didRequestHalftimeDurationCue: Bool = false
    private let lifecycleHaptics: MatchLifecycleHapticsProviding

    // Persist current context so pause/resume can compute correctly
    private var activeMatch: Match?
    private var activePeriod: Int = 1

    // Closures supplied by VM/UI
    private var onTick: ((Snapshot) -> Void)?
    private var onPeriodEnd: (() -> Void)?

    public init(lifecycleHaptics: MatchLifecycleHapticsProviding = NoopMatchLifecycleHaptics()) {
        self.lifecycleHaptics = lifecycleHaptics
    }

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
        self.didRequestHalftimeDurationCue = false

        halftimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.halfTimeStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            let label = self.formatMMSS(elapsed)
            DispatchQueue.main.async {
                onTick(label)
            }
            self.requestHalftimeDurationCueIfNeeded(elapsed: elapsed, threshold: match.halfTimeLength)
        }
        if let t = halftimeTimer { RunLoop.current.add(t, forMode: .common) }
    }

    public func restorePeriod(
        match: Match,
        currentPeriod: Int,
        persistenceState: PersistenceState,
        isPaused: Bool,
        onTick: @escaping (Snapshot) -> Void,
        onPeriodEnd: @escaping () -> Void
    ) {
        self.activeMatch = match
        self.activePeriod = currentPeriod
        self.onTick = onTick
        self.onPeriodEnd = onPeriodEnd

        stopPeriodTimer()
        stopStoppageTimer()
        stopHalftimeTimer()

        self.periodStartTime = persistenceState.periodStartTime ?? Date()
        self.halfTimeStartTime = persistenceState.halfTimeStartTime
        self.stoppageStartTime = persistenceState.stoppageStartTime
        self.stoppageAccumulated = persistenceState.stoppageAccumulated
        self.lastSnapshot = self.snapshot(at: Date(), isInStoppage: persistenceState.isInStoppage)

        if isPaused == false {
            startPeriodTimer()
        }
        if persistenceState.isInStoppage {
            startStoppageTimer()
        }

        DispatchQueue.main.async {
            onTick(self.lastSnapshot)
        }
    }

    public func restoreHalfTime(
        match: Match,
        persistenceState: PersistenceState,
        onTick: @escaping (String) -> Void
    ) {
        stopHalftimeTimer()
        self.halfTimeStartTime = persistenceState.halfTimeStartTime ?? Date()
        self.didRequestHalftimeDurationCue = persistenceState.didRequestHalftimeDurationCue

        let elapsed = Date().timeIntervalSince(self.halfTimeStartTime ?? Date())
        DispatchQueue.main.async {
            onTick(self.formatMMSS(elapsed))
        }
        self.requestHalftimeDurationCueIfNeeded(elapsed: elapsed, threshold: match.halfTimeLength)

        halftimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.halfTimeStartTime else { return }
            let currentElapsed = Date().timeIntervalSince(start)
            let label = self.formatMMSS(currentElapsed)
            DispatchQueue.main.async {
                onTick(label)
            }
            self.requestHalftimeDurationCueIfNeeded(elapsed: currentElapsed, threshold: match.halfTimeLength)
        }
        if let t = halftimeTimer { RunLoop.current.add(t, forMode: .common) }
    }

    public func persistenceState() -> PersistenceState {
        PersistenceState(
            periodStartTime: self.periodStartTime,
            halfTimeStartTime: self.halfTimeStartTime,
            stoppageStartTime: self.stoppageStartTime,
            stoppageAccumulated: self.stoppageAccumulated,
            isInStoppage: self.lastSnapshot.isInStoppage,
            didRequestHalftimeDurationCue: self.didRequestHalftimeDurationCue)
    }

    /// Stops half-time updates.
    public func stopHalfTime() {
        stopHalftimeTimer()
        halfTimeStartTime = nil
        didRequestHalftimeDurationCue = false
        lifecycleHaptics.cancelPendingPlayback()
    }

    /// Stops all timers and clears callbacks. Safe to call multiple times.
    public func stopAll() {
        stopPeriodTimer()
        stopStoppageTimer()
        stopHalftimeTimer()
        didRequestHalftimeDurationCue = false
        onTick = nil
        onPeriodEnd = nil
        activeMatch = nil
        lifecycleHaptics.cancelPendingPlayback()
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
        guard self.activeMatch != nil, self.periodStartTime != nil else { return }

        let snapshot = self.snapshot(at: Date(), isInStoppage: self.lastSnapshot.isInStoppage)
        self.lastSnapshot = snapshot
        if let onTick = onTick {
            DispatchQueue.main.async { onTick(snapshot) }
        }

        // End of period
        if let match = self.activeMatch,
           let start = self.periodStartTime,
           Date().timeIntervalSince(start) >= self.perPeriodDurationSeconds(for: match, currentPeriod: self.activePeriod)
        {
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

    private func requestHalftimeDurationCueIfNeeded(elapsed: TimeInterval, threshold: TimeInterval) {
        guard elapsed >= threshold, !self.didRequestHalftimeDurationCue else { return }
        self.didRequestHalftimeDurationCue = true
        self.lifecycleHaptics.play(.halftimeDurationReached)
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

    private func snapshot(at now: Date, isInStoppage: Bool) -> Snapshot {
        guard let match = self.activeMatch, let periodStartTime = self.periodStartTime else {
            return self.lastSnapshot
        }

        let periodElapsed = now.timeIntervalSince(periodStartTime)
        let perDuration = self.perPeriodDurationSeconds(for: match, currentPeriod: self.activePeriod)
        let remaining = max(0, perDuration - periodElapsed)

        var priorDurations: TimeInterval = 0
        if self.activePeriod > 1 {
            for period in 1..<self.activePeriod {
                priorDurations += self.perPeriodDurationSeconds(for: match, currentPeriod: period)
            }
        }
        let totalMatchElapsed = priorDurations + periodElapsed

        var snapshot = self.lastSnapshot
        snapshot.periodTime = self.formatMMSS(periodElapsed)
        snapshot.periodTimeRemaining = self.formatMMSS(remaining)
        snapshot.matchTime = self.formatMMSS(totalMatchElapsed)
        snapshot.isInStoppage = isInStoppage
        if isInStoppage, let stopStart = self.stoppageStartTime {
            let currentStoppage = self.stoppageAccumulated + now.timeIntervalSince(stopStart)
            snapshot.formattedStoppageTime = self.formatMMSS(currentStoppage)
        } else {
            snapshot.formattedStoppageTime = self.formatMMSS(self.stoppageAccumulated)
        }
        return snapshot
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let mm = total / 60
        let ss = total % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}
