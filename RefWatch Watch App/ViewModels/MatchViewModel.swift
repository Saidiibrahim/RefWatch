//
//  MatchViewModel.swift
//  RefereeAssistant
//
//  Description: ViewModel controlling the logic for a match (e.g., timer).
//

import Foundation
import SwiftUI

class MatchViewModel: ObservableObject {
    @Published var match = Match()
    @Published var formattedElapsedTime: String = "00:00"
    
    private var timer: Timer?
    
    func startMatch() {
        match.startTime = Date()
        startTimer()
    }
    
    private func startTimer() {
        // Invalidate any existing timer before creating a new one
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateElapsedTime()
        }
    }
    
    private func updateElapsedTime() {
        guard let startTime = match.startTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        match.duration = elapsed
        
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        
        formattedElapsedTime = String(format: "%02d:%02d", minutes, seconds)
    }
    
    func stopMatch() {
        timer?.invalidate()
        timer = nil
    }
}
