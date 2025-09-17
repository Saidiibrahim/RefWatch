import SwiftUI
import RefWorkoutCore

struct WorkoutHomeView: View {
  let authorization: WorkoutAuthorizationStatus
  let presets: [WorkoutPreset]
  let lastCompleted: WorkoutSession?
  let isBusy: Bool
  let onRequestAccess: () -> Void
  let onStartPreset: (WorkoutPreset) -> Void
  let onQuickStart: (WorkoutKind) -> Void
  let onReload: () -> Void

  private var quickStartKinds: [WorkoutKind] {
    [.outdoorRun, .outdoorWalk, .strength, .mobility]
  }

  var body: some View {
    List {
      if authorization.state != .authorized {
        authorizationSection
      }

      if let lastCompleted {
        Section("Recent") {
          VStack(alignment: .leading, spacing: 6) {
            Text(lastCompleted.title)
              .font(.headline)
            Text(summary(for: lastCompleted))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
        }
      }

      Section("Quick start") {
        ForEach(quickStartKinds, id: \.self) { kind in
          Button {
            onQuickStart(kind)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: icon(for: kind))
                .foregroundColor(.accentColor)
              VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                Text(quickStartSubtitle(for: kind))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              if isBusy {
                ProgressView()
                  .progressViewStyle(.circular)
              }
            }
            .padding(.vertical, 4)
          }
          .buttonStyle(.plain)
          .disabled(isBusy)
        }
      }

      Section("Presets") {
        if presets.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            if isBusy {
              ProgressView()
                .progressViewStyle(.circular)
            } else {
              Text("No presets found")
                .font(.caption)
                .foregroundStyle(.secondary)
              Button("Load example presets", action: onReload)
                .disabled(isBusy)
            }
          }
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 6)
        } else {
          ForEach(presets) { preset in
            Button {
              onStartPreset(preset)
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(preset.title)
                    .font(.headline)
                  Spacer()
                  if isBusy {
                    ProgressView()
                      .progressViewStyle(.circular)
                  }
                }
                Text(presetSummary(preset))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
          }
        }
      }
    }
    .listStyle(.carousel)
  }
}

private extension WorkoutHomeView {
  var authorizationSection: some View {
    Section("Permissions") {
      VStack(alignment: .leading, spacing: 6) {
        Text(authorizationMessage)
          .font(.caption)
        Button(action: onRequestAccess) {
          if isBusy {
            ProgressView()
          } else {
            Text(authorizationButtonTitle)
          }
        }
        .disabled(isBusy)
      }
      .padding(.vertical, 4)
    }
  }

  var authorizationMessage: String {
    switch authorization.state {
    case .notDetermined:
      return "Grant Health permissions so RefZone can log distance, heart-rate, and energy for your workout sessions."
    case .denied:
      return "Health permissions are denied. Update access in the Settings app to unlock workout tracking."
    case .limited:
      return "RefZone has limited Health access. Enable all metrics for complete analysis."
    case .authorized:
      return ""
    }
  }

  var authorizationButtonTitle: String {
    switch authorization.state {
    case .notDetermined:
      return "Grant Access"
    case .denied, .limited:
      return "Review Access"
    case .authorized:
      return ""
    }
  }

  func summary(for session: WorkoutSession) -> String {
    var components: [String] = []
    if let duration = session.totalDuration ?? session.summary.duration {
      components.append(formatDuration(duration))
    }
    if let distance = session.summary.totalDistance {
      components.append(formatKilometres(distance))
    }
    return components.joined(separator: " • ")
  }

  func presetSummary(_ preset: WorkoutPreset) -> String {
    var values: [String] = []
    let duration = preset.totalPlannedDuration
    if duration > 0 {
      values.append(formatDuration(duration))
    }
    let distance = preset.totalPlannedDistance
    if distance > 0 {
      values.append(formatKilometres(distance))
    }
    return values.joined(separator: " • ")
  }

  func formatDuration(_ time: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter.string(from: time) ?? "0m"
  }

  func formatKilometres(_ meters: Double) -> String {
    let kilometres = meters / 1000
    return String(format: "%.1f km", kilometres)
  }

  func icon(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun, .indoorRun:
      return "figure.run"
    case .outdoorWalk:
      return "figure.walk"
    case .indoorCycle:
      return "bicycle"
    case .strength:
      return "dumbbell"
    case .mobility:
      return "figure.cooldown"
    case .refereeDrill:
      return "whistle"
    case .custom:
      return "star"
    }
  }

  func quickStartSubtitle(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun, .indoorRun:
      return "Auto-pause + splits"
    case .outdoorWalk:
      return "Distance & pace logging"
    case .indoorCycle:
      return "Cadence ready"
    case .strength:
      return "Supersets tracking"
    case .mobility:
      return "Guided intervals"
    case .refereeDrill:
      return "Match sprint repeats"
    case .custom:
      return "Build your own"
    }
  }
}
