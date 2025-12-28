import SwiftUI
import AppIntents
import RefWatchCore

struct RectangularView: View {
  let state: LiveActivityState?

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      leadingContent

      Spacer(minLength: 0)

      if #available(watchOS 10.0, *), let controlType = controlType {
        controlButton(for: controlType)
      }
    }
  }

  private var leadingContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("REFZONE")
        .font(.system(size: 13, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      timeContent
    }
  }

  @ViewBuilder
  private var timeContent: some View {
    if let s = state, let end = s.expectedPeriodEnd, s.isPaused == false {
      // Running timer uses live interval updates.
      Text(timerInterval: s.periodStart...end)
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    } else if let s = state, let elapsed = s.elapsedAtPause {
      // Paused match shows fixed elapsed time snapshot.
      Text(Self.formatMMSS(elapsed))
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    } else {
      Text("No Active Match")
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  @available(watchOS 10.0, *)
  private var controlType: ControlType? {
    if state?.canPause == true { return .pause }
    if state?.canResume == true { return .resume }
    return nil
  }

  @available(watchOS 10.0, *)
  private func controlButton(for type: ControlType) -> AnyView {
    switch type {
    case .pause:
      return AnyView(controlButton(systemName: "pause.fill", intent: PauseMatchIntent(), label: "Pause match"))
    case .resume:
      return AnyView(controlButton(systemName: "play.fill", intent: ResumeMatchIntent(), label: "Resume match"))
    }
  }

  @available(watchOS 10.0, *)
  private func controlButton<I: AppIntent>(systemName: String, intent: I, label: String) -> some View {
    Button(intent: intent) {
      Image(systemName: systemName)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(Color.white)
        .frame(width: 48, height: 48)
        .background(
          Circle()
            .fill(ControlColors.background)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private static func formatMMSS(_ t: TimeInterval) -> String {
    let total = max(0, Int(t))
    let mm = total / 60
    let ss = total % 60
    return String(format: "%02d:%02d", mm, ss)
  }
}

@available(watchOS 10.0, *)
private extension RectangularView {
  enum ControlType {
    case pause
    case resume
  }

  enum ControlColors {
    static let background = ColorPalette.standard.accentSecondary
  }
}
