// File: TimerService.swift
// New service to handle all timer-related logic

import Foundation
import Observation

@Observable final class TimerService {
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var isRunning = false
    private var timer: Timer?
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        pause()
        elapsedTime = 0
    }
    
    func formattedTime() -> String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 