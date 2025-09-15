import SwiftUI

struct CircularView: View {
  let state: LiveActivityState?

  var body: some View {
    ZStack {
      if let s = state, let end = s.expectedPeriodEnd, s.isPaused == false {
        VStack(spacing: 2) {
          Text(timerInterval: s.periodStart...end)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .monospacedDigit()
          HStack(spacing: 4) {
            if s.isPaused { Image(systemName: "pause.fill") }
            if s.isInStoppage { Image(systemName: "stopwatch") }
          }
          .font(.system(size: 10))
        }
      } else if let s = state, let elapsed = s.elapsedAtPause {
        Text(Self.formatMMSS(elapsed))
          .font(.system(size: 16, weight: .semibold, design: .rounded))
          .monospacedDigit()
      } else {
        Text("—:—")
          .font(.system(size: 16, weight: .semibold, design: .rounded))
      }
    }
  }

  private static func formatMMSS(_ t: TimeInterval) -> String {
    let total = max(0, Int(t))
    let mm = total / 60
    let ss = total % 60
    return String(format: "%02d:%02d", mm, ss)
  }
}
