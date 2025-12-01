//
//  CountdownRingView.swift
//  RefZoneWatchOS
//
//  Description: Visual countdown ring component matching Apple Workout style
//  Displays circular progress ring with countdown numbers (Ready → 3 → 2 → 1)
//

import SwiftUI
import RefWatchCore

/// Countdown ring view matching Apple Workout app style
/// Shows circular progress ring with countdown text in center
struct CountdownRingView: View {
  @Bindable var viewModel: CountdownRingViewModel
  @Environment(\.theme) private var theme
  @Environment(\.haptics) private var haptics
  
  // Ring configuration
  private let ringSize: CGFloat = 120
  private let ringLineWidth: CGFloat = 8
  private let ringColor = Color.green // Match Apple Workout green
  
  var body: some View {
    // Countdown ring and text - centered on screen
    VStack(spacing: theme.spacing.m) {
      // Circular countdown ring
      ZStack {
        // Background ring (unfilled portion) - always visible
        Circle()
          .stroke(Color.gray.opacity(0.3), lineWidth: ringLineWidth)
          .frame(width: ringSize, height: ringSize)
        
        // Progress ring (filled portion)
        // During Ready: ring is full (100%) and static with no animation
        // During Counting: ring gradually reduces from current value to target value over 1 second
        // Progress values: Ready = 100%, 3 = 75%, 2 = 50%, 1 = 25%, Complete = 0%
        Circle()
          .trim(from: 0, to: viewModel.progress)
          .stroke(
            ringColor,
            style: StrokeStyle(
              lineWidth: ringLineWidth,
              lineCap: .round
            )
          )
          .frame(width: ringSize, height: ringSize)
          .rotationEffect(.degrees(-90)) // Start from top
        
        // Center text (Ready, 3, 2, or 1)
        Text(centerText)
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity) // Center on screen
    .onChange(of: viewModel.currentPhase) { oldPhase, newPhase in
      // Trigger haptic feedback on phase changes
      handlePhaseChange(from: oldPhase, to: newPhase)
      
      // Update progress ring based on phase
      switch newPhase {
      case .ready:
        // Ready phase: ring is full (100%) and static with no animation
        viewModel.progress = 1.0
      case .counting(let number):
        // Counting phase: ring reduces from current value to target value over 1 second
        // Target values: 3 = 75%, 2 = 50%, 1 = 25%
        let targetProgress = viewModel.progressForCountdown(number)
        withAnimation(.linear(duration: 1.0)) {
          viewModel.progress = targetProgress
        }
      case .complete:
        // Complete phase: ring reduces to 0% (no animation)
        viewModel.progress = 0.0
      }
    }
    .onAppear {
      // Initialize progress ring based on current phase when view appears
      switch viewModel.currentPhase {
      case .ready:
        // Ready phase: ring is full (100%) and static with no animation
        viewModel.progress = 1.0
      case .counting(let number):
        // Counting phase: set to target progress value and animate if needed
        let targetProgress = viewModel.progressForCountdown(number)
        // Only animate if we're not already at the target (e.g., if view appears mid-countdown)
        if abs(viewModel.progress - targetProgress) > 0.01 {
          withAnimation(.linear(duration: 1.0)) {
            viewModel.progress = targetProgress
          }
        } else {
          viewModel.progress = targetProgress
        }
      case .complete:
        // Complete phase: ring is at 0% (no animation)
        viewModel.progress = 0.0
      }
    }
  }
  
  /// Text displayed in center of ring based on current phase
  private var centerText: String {
    switch viewModel.currentPhase {
    case .ready:
      return "Ready"
    case .counting(let number):
      return "\(number)"
    case .complete:
      return "1" // Show 1 briefly before completion
    }
  }
  
  /// Handles haptic feedback on phase transitions
  private func handlePhaseChange(from oldPhase: CountdownRingViewModel.Phase, to newPhase: CountdownRingViewModel.Phase) {
    switch newPhase {
    case .ready:
      // Light haptic when showing "Ready"
      haptics.play(.tap)
    case .counting(let number):
      // Stronger haptic for each countdown number
      haptics.play(.start)
    case .complete:
      // Success haptic when countdown completes
      haptics.play(.success)
    }
  }
}

#Preview("Countdown Ring") {
  let viewModel = CountdownRingViewModel()
  
  return CountdownRingView(viewModel: viewModel)
    .hapticsProvider(WatchHaptics())
    .onAppear {
      viewModel.start {
        print("Countdown complete!")
      }
    }
}

