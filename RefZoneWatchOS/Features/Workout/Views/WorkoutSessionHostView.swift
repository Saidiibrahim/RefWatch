import SwiftUI
import RefWorkoutCore

struct WorkoutSessionHostView: View {
  let session: WorkoutSession
  let isPaused: Bool
  let isEnding: Bool
  let onPause: () -> Void
  let onResume: () -> Void
  let onEnd: () -> Void

  @State private var timerModel: WorkoutTimerFaceModel

  init(
    session: WorkoutSession,
    isPaused: Bool,
    isEnding: Bool,
    onPause: @escaping () -> Void,
    onResume: @escaping () -> Void,
    onEnd: @escaping () -> Void
  ) {
    self.session = session
    self.isPaused = isPaused
    self.isEnding = isEnding
    self.onPause = onPause
    self.onResume = onResume
    self.onEnd = onEnd
    _timerModel = State(initialValue: WorkoutTimerFaceModel(session: session, onPause: onPause, onResume: onResume))
  }

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 10) {
          Text(session.title)
            .font(.headline)
          if let preset = session.presetId {
            Text("Preset #\(preset.uuidString.prefix(6))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          TimerFaceFactory.view(for: .standard, model: timerModel)
            .hapticsProvider(WatchHaptics())
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
      }

      if hasMetrics {
        metricsSection
      }

      if !session.segments.isEmpty {
        Section("Segments") {
          ForEach(session.segments) { segment in
            VStack(alignment: .leading, spacing: 4) {
              Text(segment.name)
              HStack(spacing: 8) {
                if let duration = segment.plannedDuration {
                  Text(formatDuration(duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                if let distance = segment.plannedDistance {
                  Text(formatDistance(distance))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                if let zone = segment.target?.intensityZone {
                  Text(zone.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }
            }
            .padding(.vertical, 4)
          }
        }
      }

      Section("Controls") {
        Button {
          if isPaused {
            timerModel.resumeMatch()
          } else {
            timerModel.pauseMatch()
          }
        } label: {
          HStack {
            Text(isPaused ? "Resume" : "Pause")
            Spacer()
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
          }
        }
        .disabled(isEnding)

        Button(role: .destructive) {
          onEnd()
        } label: {
          if isEnding {
            ProgressView()
          } else {
            Text("End Session")
          }
        }
        .disabled(isEnding)
      }
    }
    .listStyle(.carousel)
    .onAppear {
      timerModel.updatePauseState(isPaused)
    }
    .onChange(of: session) { newValue in
      timerModel.updateSession(newValue)
    }
    .onChange(of: isPaused) { paused in
      timerModel.updatePauseState(paused)
    }
  }
}

private extension WorkoutSessionHostView {
  var metricsSection: some View {
    Section("Metrics") {
      if let duration = session.summary.duration ?? session.totalDuration {
        metricRow(title: "Duration", value: formatDuration(duration))
      }
      if let distance = session.summary.totalDistance {
        metricRow(title: "Distance", value: formatDistance(distance))
      }
      if let averageHR = session.summary.averageHeartRate {
        metricRow(title: "Avg HR", value: String(format: "%.0f bpm", averageHR))
      }
      if let maxHR = session.summary.maximumHeartRate {
        metricRow(title: "Max HR", value: String(format: "%.0f bpm", maxHR))
      }
    }
  }

  func metricRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text(value)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }

  var hasMetrics: Bool {
    let duration = session.summary.duration ?? session.totalDuration
    return duration != nil || session.summary.totalDistance != nil || session.summary.averageHeartRate != nil || session.summary.maximumHeartRate != nil
  }

  func formatDuration(_ interval: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter.string(from: interval) ?? "0m"
  }

  func formatDistance(_ meters: Double) -> String {
    String(format: "%.1f km", meters / 1000)
  }
}
