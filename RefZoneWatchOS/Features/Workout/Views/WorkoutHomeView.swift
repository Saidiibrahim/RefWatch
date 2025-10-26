import SwiftUI
import RefWatchCore
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

  @Environment(\.theme) private var theme

  private var quickStartKinds: [WorkoutKind] {
    [.outdoorRun, .outdoorWalk, .strength, .mobility]
  }

  var body: some View {
    List {
      if authorization.state != .authorized || authorization.hasOptionalLimitations {
        Section("Permissions") {
          if authorization.state != .authorized {
            WorkoutPermissionsCard(
              message: authorizationMessage,
              buttonTitle: authorizationButtonTitle,
              isBusy: isBusy,
              onRequestAccess: onRequestAccess
            )
            .listRowInsets(cardInsets)
            .listRowBackground(Color.clear)
          }

          if let diagnosticsMessage {
            WorkoutAuthorizationDiagnosticsBadge(message: diagnosticsMessage)
              .listRowInsets(cardInsets)
              .listRowBackground(Color.clear)
          }
        }
      }

      if let lastCompleted {
        Section("Recent") {
          WorkoutSummaryCard(session: lastCompleted, summary: summary(for: lastCompleted))
            .listRowInsets(cardInsets)
            .listRowBackground(Color.clear)
        }
      }

      Section("Quick start") {
        ForEach(quickStartKinds, id: \.self) { kind in
          Button {
            onQuickStart(kind)
          } label: {
            WorkoutQuickStartCard(
              title: kind.displayName,
              subtitle: quickStartSubtitle(for: kind),
              icon: icon(for: kind),
              isBusy: isBusy
            )
          }
          .buttonStyle(.plain)
          .disabled(isBusy)
          .listRowInsets(cardInsets)
          .listRowBackground(Color.clear)
        }
      }

      Section("Presets") {
        if presets.isEmpty {
          WorkoutEmptyPresetsCard(isBusy: isBusy, onReload: onReload)
            .listRowInsets(cardInsets)
            .listRowBackground(Color.clear)
        } else {
          ForEach(presets) { preset in
            Button {
              onStartPreset(preset)
            } label: {
              WorkoutPresetCard(
                title: preset.title,
                subtitle: presetSummary(preset),
                isBusy: isBusy
              )
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .listRowInsets(cardInsets)
            .listRowBackground(Color.clear)
          }
        }
      }
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .scenePadding(.horizontal)
    .padding(.vertical, theme.components.listVerticalSpacing)
    .background(theme.colors.backgroundPrimary)
  }
}

private extension WorkoutHomeView {
  var cardInsets: EdgeInsets {
    let vertical = theme.components.listRowVerticalInset
    let horizontal = theme.components.cardHorizontalPadding
    return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
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

  var diagnosticsMessage: String? {
    let optionalMetrics = authorization.deniedOptionalMetrics
    guard !optionalMetrics.isEmpty else { return nil }

    let names = optionalMetrics.map(\.displayName).sorted()
    let prefix = names.count == 1 ? "Optional metric unavailable" : "Optional metrics unavailable"
    return "\(prefix): \(names.joined(separator: ", "))"
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

private struct WorkoutQuickStartCard: View {
  @Environment(\.theme) private var theme
  let title: String
  let subtitle: String
  let icon: String
  let isBusy: Bool

  var body: some View {
    // Styled to match SettingsNavigationRow for consistency across the app
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: theme.spacing.m) {
        Image(systemName: icon)
          .font(.title2)
          .foregroundStyle(theme.colors.accentSecondary)

        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(title)
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)
            .lineLimit(1)

          Text(subtitle)
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // Only show accessory when busy - no chevron for action buttons
        if isBusy {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(theme.colors.textSecondary)
        }
      }
    }
  }
}

private struct WorkoutPresetCard: View {
  @Environment(\.theme) private var theme
  let title: String
  let subtitle: String
  let isBusy: Bool

  var body: some View {
    // Styled to match SettingsNavigationRow for consistency across the app
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: theme.spacing.m) {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(title)
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)
            .lineLimit(1)

          if !subtitle.isEmpty {
            Text(subtitle)
              .font(theme.typography.cardMeta)
              .foregroundStyle(theme.colors.textSecondary)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // Only show accessory when busy - no chevron for action buttons
        if isBusy {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(theme.colors.textSecondary)
        }
      }
    }
  }
}

private struct WorkoutSummaryCard: View {
  @Environment(\.theme) private var theme
  let session: WorkoutSession
  let summary: String

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Text(session.title)
          .font(theme.typography.cardHeadline)
          .foregroundStyle(theme.colors.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.75)

        if !summary.isEmpty {
          Text(summary)
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
        }
      }
    }
  }
}

private struct WorkoutPermissionsCard: View {
  @Environment(\.theme) private var theme
  let message: String
  let buttonTitle: String
  let isBusy: Bool
  let onRequestAccess: () -> Void

  var body: some View {
    Button(action: onRequestAccess) {
      ThemeCardContainer(role: .secondary) {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
          Text(message)
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
            .multilineTextAlignment(.leading)

          if !buttonTitle.isEmpty {
            Text(buttonTitle)
              .font(theme.typography.button)
              .foregroundStyle(theme.colors.textInverted)
              .frame(maxWidth: .infinity)
              .padding(.vertical, theme.spacing.s)
              .background(
                RoundedRectangle(cornerRadius: theme.components.controlCornerRadius, style: .continuous)
                  .fill(theme.colors.accentSecondary)
              )
          }
        }
      }
      .overlay {
        if isBusy {
          RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
            .fill(theme.colors.surfaceOverlay)
            .overlay(
              ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.colors.textPrimary)
            )
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(isBusy)
  }
}

private struct WorkoutAuthorizationDiagnosticsBadge: View {
  @Environment(\.theme) private var theme
  let message: String

  var body: some View {
    HStack(spacing: theme.spacing.xs) {
      Image(systemName: "info.circle")
        .font(theme.typography.iconSecondary)
        .foregroundStyle(theme.colors.accentSecondary)

      Text(message)
        .font(theme.typography.cardMeta)
        .foregroundStyle(theme.colors.accentSecondary)
        .multilineTextAlignment(.leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, theme.spacing.xs)
    .padding(.horizontal, theme.spacing.s)
    .background(
      Capsule()
        .fill(theme.colors.accentSecondary.opacity(0.16))
    )
  }
}

private struct WorkoutEmptyPresetsCard: View {
  @Environment(\.theme) private var theme
  let isBusy: Bool
  let onReload: () -> Void

  var body: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        Text("No presets found")
          .font(theme.typography.cardMeta)
          .foregroundStyle(theme.colors.textSecondary)

        Button(action: onReload) {
          if isBusy {
            ProgressView()
              .progressViewStyle(.circular)
          } else {
            Text("Load example presets")
              .font(theme.typography.button)
          }
        }
        .buttonStyle(.bordered)
        .tint(theme.colors.accentSecondary)
        .controlSize(.large)
        .disabled(isBusy)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview("Workout Home") {
  WorkoutHomeView(
    authorization: WorkoutAuthorizationStatus(state: .authorized),
    presets: WorkoutHomePreviewData.presets,
    lastCompleted: WorkoutHomePreviewData.lastCompleted,
    isBusy: false,
    onRequestAccess: {},
    onStartPreset: { _ in },
    onQuickStart: { _ in },
    onReload: {}
  )
  .theme(DefaultTheme())
}

#Preview("Workout Home – Permissions") {
  WorkoutHomeView(
    authorization: WorkoutAuthorizationStatus(state: .notDetermined),
    presets: [],
    lastCompleted: nil,
    isBusy: false,
    onRequestAccess: {},
    onStartPreset: { _ in },
    onQuickStart: { _ in },
    onReload: {}
  )
  .theme(DefaultTheme())
}

private enum WorkoutHomePreviewData {
  static let lastCompleted: WorkoutSession = .init(
    state: .ended,
    kind: .outdoorWalk,
    title: "Outdoor Walk",
    startedAt: Date().addingTimeInterval(-2_400),
    endedAt: Date().addingTimeInterval(-300),
    segments: [
      WorkoutSegment(name: "Warm-up", purpose: .warmup, plannedDuration: 300, plannedDistance: 0.4),
      WorkoutSegment(name: "Intervals", purpose: .work, plannedDuration: 1_200, plannedDistance: 2.0)
    ],
    summary: .init(
      averageHeartRate: 118,
      maximumHeartRate: 152,
      totalDistance: 3_500,
      duration: 1_800
    )
  )

  static let presets: [WorkoutPreset] = [
    WorkoutPreset(
      title: "Tempo Intervals",
      kind: .refereeDrill,
      segments: [
        WorkoutSegment(name: "Build", purpose: .warmup, plannedDuration: 300, plannedDistance: 0.5),
        WorkoutSegment(name: "Tempo", purpose: .work, plannedDuration: 600, plannedDistance: 1.6,
                       target: .init(intensityZone: .tempo)),
        WorkoutSegment(name: "Recover", purpose: .recovery, plannedDuration: 300, plannedDistance: 0.5)
      ]
    ),
    WorkoutPreset(
      title: "Match Sprint Repeats",
      kind: .refereeDrill,
      segments: [
        WorkoutSegment(name: "Sprints", purpose: .work, plannedDuration: 420, plannedDistance: 1.2,
                       target: .init(intensityZone: .anaerobic)),
        WorkoutSegment(name: "Jog", purpose: .recovery, plannedDuration: 300, plannedDistance: 0.6)
      ]
    )
  ]
}
