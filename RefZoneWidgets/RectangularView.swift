import SwiftUI

struct RectangularView: View {
  let state: LiveActivityState?

  var body: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 2) {
        Text(state?.periodLabel ?? "Match")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.primary)

        if let s = state, let end = s.expectedPeriodEnd, s.isPaused == false {
          // Running timer
          Text(timerInterval: s.periodStart...end)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
        } else if let s = state, let elapsed = s.elapsedAtPause {
          // Paused: render static elapsed
          Text(Self.formatMMSS(elapsed))
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
        } else {
          Text("No Active Match")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }

        // Bottom strip: score + stoppage/paused indicators
        HStack(spacing: 6) {
          Text("\(state?.homeAbbr ?? "HOM") \(state?.homeScore ?? 0)")
          Text("•")
          Text("\(state?.awayScore ?? 0) \(state?.awayAbbr ?? "AWA")")
          if state?.isPaused == true { Image(systemName: "pause.fill") }
          if state?.isInStoppage == true { Image(systemName: "stopwatch") }
        }
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)
    }
  }

  private static func formatMMSS(_ t: TimeInterval) -> String {
    let total = max(0, Int(t))
    let mm = total / 60
    let ss = total % 60
    return String(format: "%02d:%02d", mm, ss)
  }
}
