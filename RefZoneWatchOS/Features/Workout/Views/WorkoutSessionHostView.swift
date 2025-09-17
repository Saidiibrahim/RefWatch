import SwiftUI
import RefWorkoutCore

struct WorkoutSessionHostView: View {
  let session: WorkoutSession
  let isEnding: Bool
  let onEnd: () -> Void

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text(session.title)
            .font(.headline)
          if let preset = session.presetId {
            Text("Preset #\(preset.uuidString.prefix(6))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            Text(elapsedString(asOf: context.date))
              .font(.system(.title3, design: .rounded, weight: .semibold))
          }
        }
        .padding(.vertical, 4)
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

      Section {
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
  }
}

private extension WorkoutSessionHostView {
  func elapsedString(asOf date: Date) -> String {
    let duration = session.elapsedDuration(asOf: date)
    return formatDuration(duration)
  }

  func formatDuration(_ interval: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.zeroFormattingBehavior = [.pad]
    return formatter.string(from: interval) ?? "00:00"
  }

  func formatDistance(_ meters: Double) -> String {
    String(format: "%.1f km", meters / 1000)
  }
}
