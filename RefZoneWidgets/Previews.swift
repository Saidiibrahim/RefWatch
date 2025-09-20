import WidgetKit
import SwiftUI

// MARK: - Demo States

enum DemoStates {
  static let running: LiveActivityState = {
    let now = Date()
    return LiveActivityState(
      version: 1,
      matchIdentifier: "demo",
      homeAbbr: "HOM",
      awayAbbr: "AWA",
      homeScore: 1,
      awayScore: 0,
      periodLabel: "First Half",
      isPaused: false,
      isInStoppage: false,
      periodStart: now.addingTimeInterval(-600),
      expectedPeriodEnd: now.addingTimeInterval(600),
      elapsedAtPause: nil,
      stoppageAccumulated: 0,
      canPause: true,
      lastUpdated: now
    )
  }()

  static let paused: LiveActivityState = {
    let now = Date()
    return LiveActivityState(
      version: 1,
      matchIdentifier: "demo",
      homeAbbr: "HOM",
      awayAbbr: "AWA",
      homeScore: 2,
      awayScore: 2,
      periodLabel: "Second Half",
      isPaused: true,
      isInStoppage: true,
      periodStart: now.addingTimeInterval(-1200),
      expectedPeriodEnd: nil,
      elapsedAtPause: 1234,
      stoppageAccumulated: 42,
      canResume: true,
      lastUpdated: now
    )
  }()

  static let halftime: LiveActivityState = {
    let now = Date()
    return LiveActivityState(
      version: 1,
      matchIdentifier: "demo",
      homeAbbr: "HOM",
      awayAbbr: "AWA",
      homeScore: 1,
      awayScore: 1,
      periodLabel: "Half Time",
      isPaused: true,
      isInStoppage: false,
      periodStart: now,
      expectedPeriodEnd: nil,
      elapsedAtPause: 0,
      stoppageAccumulated: 0,
      lastUpdated: now
    )
  }()

  static let finished: LiveActivityState = {
    let now = Date()
    return LiveActivityState(
      version: 1,
      matchIdentifier: "demo",
      homeAbbr: "HOM",
      awayAbbr: "AWA",
      homeScore: 3,
      awayScore: 2,
      periodLabel: "Full Time",
      isPaused: false,
      isInStoppage: false,
      periodStart: now,
      expectedPeriodEnd: nil,
      elapsedAtPause: nil,
      stoppageAccumulated: 0,
      lastUpdated: now
    )
  }()
}

// MARK: - Previews

struct RefZoneWidgets_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      RectangularView(state: DemoStates.running)
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))

      RectangularView(state: DemoStates.paused)
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))

      CircularView(state: DemoStates.running)
        .previewContext(WidgetPreviewContext(family: .accessoryCircular))

      CircularView(state: DemoStates.paused)
        .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
  }
}
