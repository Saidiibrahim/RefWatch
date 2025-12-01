//
//  CountdownRingViewModel.swift
//  RefZoneWatchOS
//
//  Description: ViewModel managing countdown ring state and progression
//  through Ready → 3 → 2 → 1 → Complete stages
//

import Foundation
import RefWatchCore

/// ViewModel managing countdown ring progression with one-second intervals
/// States: ready → 3 → 2 → 1 → complete
@Observable
final class CountdownRingViewModel {
  /// Current countdown phase
  enum Phase: Equatable {
    case ready
    case counting(Int) // 3, 2, or 1
    case complete
  }
  
  /// Current countdown phase
  var currentPhase: Phase = .ready
  
  /// Progress value for ring animation (0.0 to 1.0)
  var progress: Double = 0.0
  
  /// Whether countdown is currently active
  var isActive: Bool = false
  
  /// Callback invoked when countdown completes
  var onComplete: (() -> Void)?
  
  /// Starts the countdown sequence
  /// - Parameter onComplete: Callback invoked when countdown finishes
  func start(onComplete: @escaping () -> Void) {
    // Store completion callback
    self.onComplete = onComplete
    
    // Reset state - start with Ready phase and 100% full ring
    currentPhase = .ready
    progress = 1.0 // Start at 100% full for Ready phase
    isActive = true
    
    // After 1 second, advance to countdown (ring will reduce from 100% to 75%)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.advanceToCountdown()
    }
  }
  
  /// Advances to the numeric countdown phase (3, 2, 1)
  private func advanceToCountdown() {
    // Start with 3 - ring reduces from 100% to 75% over 1 second
    currentPhase = .counting(3)
    // Progress will be animated in the view from current value (1.0) to 0.75
    
    // After 1 second, advance to next number
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.advanceToNextNumber()
    }
  }
  
  /// Advances to the next countdown number or completes
  private func advanceToNextNumber() {
    switch currentPhase {
    case .counting(3):
      // Move to 2 - ring reduces from 75% to 50% over 1 second
      currentPhase = .counting(2)
      // Progress will be animated in the view from current value (0.75) to 0.50
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.advanceToNextNumber()
      }
      
    case .counting(2):
      // Move to 1 - ring reduces from 50% to 25% over 1 second
      currentPhase = .counting(1)
      // Progress will be animated in the view from current value (0.50) to 0.25
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.completeCountdown()
      }
      
    case .counting(1):
      // Should not reach here, but handle gracefully
      completeCountdown()
      
    default:
      break
    }
  }
  
  /// Completes the countdown and invokes callback
  private func completeCountdown() {
    currentPhase = .complete
    // Ring reduces to 0% when complete
    progress = 0.0
    
    // Brief delay before invoking completion
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.onComplete?()
      self?.isActive = false
    }
  }
  
  /// Calculates the target progress value for a given countdown number
  /// Progress decreases as countdown progresses: 3 = 75%, 2 = 50%, 1 = 25%
  func progressForCountdown(_ number: Int) -> Double {
    switch number {
    case 3:
      return 0.75 // 3/4 remaining
    case 2:
      return 0.50 // 2/4 remaining
    case 1:
      return 0.25 // 1/4 remaining
    default:
      return 0.0
    }
  }
  
  /// Cancels the countdown if active
  func cancel() {
    isActive = false
    currentPhase = .ready
    progress = 0.0
    onComplete = nil
  }
}

