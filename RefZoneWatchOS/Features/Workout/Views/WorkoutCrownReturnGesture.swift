import SwiftUI
import RefWatchCore

struct WorkoutCrownReturnConfiguration {
  let threshold: Double
  let debounceInterval: TimeInterval
  let rotationStep: Double
  let minimumChange: Double

  static let standard = WorkoutCrownReturnConfiguration(
    threshold: 0.26, // ~15 degrees
    debounceInterval: 0.3,
    rotationStep: 0.01,
    minimumChange: 0.002
  )
}

private struct WorkoutCrownReturnModifier: ViewModifier {
  @Environment(\.haptics) private var haptics
  let configuration: WorkoutCrownReturnConfiguration
  let onReturn: () -> Void

  @State private var crownRotation: Double = 0
  @State private var lastCrownValue: Double = 0
  @State private var accumulatedRotation: Double = 0
  @State private var pendingTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .digitalCrownRotation(
        $crownRotation,
        from: -3,
        through: 3,
        by: configuration.rotationStep,
        sensitivity: .low,
        isContinuous: true,
        isHapticFeedbackEnabled: false
      )
      .onChange(of: crownRotation) { newValue in
        handleCrownChange(newValue)
      }
      .onDisappear {
        cancelPendingTask()
      }
  }

  private func handleCrownChange(_ newValue: Double) {
    let delta = newValue - lastCrownValue
    lastCrownValue = newValue

    guard abs(delta) >= configuration.minimumChange else {
      return
    }

    if delta < 0 {
      accumulatedRotation += delta
      scheduleReturnIfNeeded()
    } else {
      resetAccumulation()
    }
  }

  private func scheduleReturnIfNeeded() {
    guard accumulatedRotation <= -configuration.threshold else {
      cancelPendingTask()
      return
    }

    cancelPendingTask()
    let expectedRotation = accumulatedRotation
    pendingTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: UInt64(configuration.debounceInterval * 1_000_000_000))
      guard !Task.isCancelled else { return }
      guard accumulatedRotation <= expectedRotation else { return }
      triggerReturn()
    }
  }

  private func triggerReturn() {
    cancelPendingTask()
    crownRotation = 0
    lastCrownValue = 0
    accumulatedRotation = 0
    haptics.play(.tap)
    onReturn()
  }

  private func resetAccumulation() {
    accumulatedRotation = 0
    cancelPendingTask()
  }

  private func cancelPendingTask() {
    pendingTask?.cancel()
    pendingTask = nil
  }
}

extension View {
  func workoutCrownReturnGesture(
    configuration: WorkoutCrownReturnConfiguration = .standard,
    onReturn: @escaping () -> Void
  ) -> some View {
    modifier(WorkoutCrownReturnModifier(configuration: configuration, onReturn: onReturn))
  }
}
