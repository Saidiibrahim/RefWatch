import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutDashboardView: View {
  @StateObject private var viewModel: WorkoutDashboardViewModel
  @State private var didLoad = false
  @State private var showError = false
  @State private var selectedPresetTitle = ""
  @State private var showStartReminder = false
  @Environment(\.theme) private var theme

  init(services: WorkoutServices) {
    _viewModel = StateObject(wrappedValue: WorkoutDashboardViewModel(services: services))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: theme.spacing.stackSpacing, pinnedViews: []) {
          if viewModel.authorization.state != .authorized {
            authorizationCard
          }

          overviewCard

          presetsSection

          historySection
        }
        .padding(.vertical, theme.spacing.l)
        .padding(.horizontal, theme.spacing.l)
      }
      .background(theme.colors.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Workout")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button { viewModel.reloadPresets() } label: {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
      .refreshable {
        await viewModel.refresh()
      }
    }
    .onAppear {
      guard !didLoad else { return }
      didLoad = true
      viewModel.load()
    }
    .onChange(of: viewModel.errorMessage) { _, message in
      showError = message != nil
    }
    .alert("Workout Error", isPresented: $showError) {
      Button("OK", role: .cancel) {
        viewModel.errorMessage = nil
      }
    } message: {
      Text(viewModel.errorMessage ?? "An unexpected error occurred.")
    }
    .alert("Start on Your Watch", isPresented: $showStartReminder) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Launch \(selectedPresetTitle) from RefZone on Apple Watch to capture live metrics.")
    }
  }
}

private extension WorkoutDashboardView {
  var authorizationCard: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(alignment: .leading, spacing: theme.spacing.s) {
        Text(authorizationMessage)
          .font(theme.typography.cardMeta)
          .foregroundStyle(theme.colors.textSecondary)

        Button(action: viewModel.requestAuthorization) {
          Text(viewModel.authorization.state == .notDetermined ? "Grant Health Access" : "Review Health Access")
            .font(theme.typography.button)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.colors.accentSecondary)
      }
    }
  }

  var overviewCard: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        Text("Overview")
          .font(theme.typography.heroSubtitle)
          .foregroundStyle(theme.colors.textPrimary)

        HStack(spacing: theme.spacing.l) {
          statBlock(title: "Presets", value: "\(viewModel.presets.count)")
          Divider()
            .background(theme.colors.outlineMuted)
          statBlock(title: "Recent Sessions", value: "\(viewModel.recentSessions.count)")
        }

        Text("Start workouts on your Apple Watch to capture real-time metrics. Presets and history stay in sync once connectivity is established.")
          .font(theme.typography.cardMeta)
          .foregroundStyle(theme.colors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  var presetsSection: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      sectionHeader("Presets")

      if viewModel.presets.isEmpty {
        ThemeCardContainer(role: .secondary) {
          Text("Create your first workout preset to build repeatable training sessions.")
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
        }
      } else {
        ForEach(viewModel.presets) { preset in
          NavigationLink {
            Text("Preset detail for \(preset.title) coming soon.")
              .padding()
              .navigationTitle(preset.title)
          } label: {
            WorkoutPresetCard(
              preset: preset,
              presetLine: presetLine(preset),
              onStart: {
                selectedPresetTitle = preset.title
                showStartReminder = true
              }
            )
          }
          .buttonStyle(.plain)
        }
      }

      Button {
        // Placeholder for preset creation flow
      } label: {
        ThemeCardContainer(role: .primary, minHeight: 72) {
          HStack(spacing: theme.spacing.m) {
            Image(systemName: "plus.circle.fill")
              .font(theme.typography.iconAccent)
              .foregroundStyle(theme.colors.textPrimary)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
              Text("New Preset")
                .font(theme.typography.heroSubtitle)
                .foregroundStyle(theme.colors.textPrimary)
              Text("Design referee-specific drills and repeats from here.")
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textPrimary.opacity(0.8))
            }
            Spacer()
          }
        }
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  var historySection: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      sectionHeader("Recent Sessions")

      if viewModel.recentSessions.isEmpty {
        ThemeCardContainer(role: .secondary) {
          Text("Completed workouts will appear here once synced from the watch.")
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
        }
      } else {
        ForEach(viewModel.recentSessions) { session in
          NavigationLink {
            Text("Session detail for \(session.title) coming soon.")
              .padding()
              .navigationTitle(session.title)
          } label: {
            WorkoutHistoryCard(
              session: session,
              summaryLine: sessionLine(session)
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  func statBlock(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Text(title)
        .font(theme.typography.cardMeta)
        .foregroundStyle(theme.colors.textSecondary)
      Text(value)
        .font(theme.typography.heroTitle)
        .foregroundStyle(theme.colors.textPrimary)
    }
  }

  func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(theme.typography.heroSubtitle)
      .foregroundStyle(theme.colors.textPrimary)
      .padding(.horizontal, theme.spacing.xs)
  }

  var authorizationMessage: String {
    switch viewModel.authorization.state {
    case .notDetermined:
      return "RefZone needs permission to read workouts, heart rate, and distance from Health to power the dashboard."
    case .denied:
      return "Health access is currently denied. Update permissions in the Health app to sync workouts."
    case .limited:
      return "Health access is limited. Allow all metrics for richer insights."
    case .authorized:
      return ""
    }
  }

  func presetLine(_ preset: WorkoutPreset) -> String {
    var parts: [String] = []
    let duration = preset.totalPlannedDuration
    if duration > 0 {
      parts.append(formatDuration(duration))
    }
    let distance = preset.totalPlannedDistance
    if distance > 0 {
      parts.append(formatDistance(distance))
    }
    parts.append(preset.kind.displayName)
    return parts.joined(separator: " • ")
  }

  func sessionLine(_ session: WorkoutSession) -> String {
    var parts: [String] = []
    if let duration = session.totalDuration ?? session.summary.duration {
      parts.append(formatDuration(duration))
    }
    if let distance = session.summary.totalDistance {
      parts.append(formatDistance(distance))
    }
    if let completed = session.endedAt {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .short
      parts.append(formatter.localizedString(for: completed, relativeTo: Date()))
    }
    return parts.joined(separator: " • ")
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

private enum ThemeCardRole {
  case primary
  case secondary
  case positive
  case destructive
}

private struct ThemeCardSurfaceStyle {
  let background: Color
  let outline: Color?
  let titleColor: Color
  let subtitleColor: Color
}

private func surfaceStyle(for role: ThemeCardRole, theme: AnyTheme) -> ThemeCardSurfaceStyle {
  switch role {
  case .primary:
    return ThemeCardSurfaceStyle(
      background: theme.colors.accentPrimary,
      outline: nil,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textPrimary.opacity(0.84)
    )
  case .secondary:
    return ThemeCardSurfaceStyle(
      background: theme.colors.backgroundElevated,
      outline: theme.colors.outlineMuted,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textSecondary
    )
  case .positive:
    return ThemeCardSurfaceStyle(
      background: theme.colors.matchPositive,
      outline: nil,
      titleColor: Color.white,
      subtitleColor: Color.white.opacity(0.85)
    )
  case .destructive:
    return ThemeCardSurfaceStyle(
      background: theme.colors.matchCritical,
      outline: nil,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textPrimary.opacity(0.84)
    )
  }
}

private struct ThemeCardContainer<Content: View>: View {
  @Environment(\.theme) private var theme

  let role: ThemeCardRole
  let minHeight: CGFloat
  let content: Content

  init(role: ThemeCardRole, minHeight: CGFloat = 0, @ViewBuilder content: () -> Content) {
    self.role = role
    self.minHeight = minHeight
    self.content = content()
  }

  var body: some View {
    let styling = surfaceStyle(for: role, theme: theme)

    content
      .padding(.vertical, theme.spacing.m)
      .padding(.horizontal, theme.components.cardHorizontalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(minHeight: minHeight, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
          .fill(styling.background)
          .overlay(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
              .stroke(styling.outline ?? .clear, lineWidth: styling.outline == nil ? 0 : 1)
          )
      )
      .shadow(
        color: Color.black.opacity(theme.components.cardShadowOpacity),
        radius: theme.components.cardShadowRadius,
        x: 0,
        y: theme.components.cardShadowYOffset
      )
      .contentShape(RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous))
  }
}

private struct WorkoutPresetCard: View {
  let preset: WorkoutPreset
  let presetLine: String
  let onStart: () -> Void
  @Environment(\.theme) private var theme

  private struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let accessibilityLabel: String
  }

  private var quickActions: [QuickAction] {
    [
      QuickAction(icon: "speaker.slash.fill", accessibilityLabel: "Mute cues"),
      QuickAction(icon: "bell.slash.fill", accessibilityLabel: "Silence reminders"),
      QuickAction(icon: "clock.arrow.circlepath", accessibilityLabel: "Repeat intervals")
    ]
  }

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 120) {
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        HStack(alignment: .top, spacing: theme.spacing.m) {
          workoutGlyph

          VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(preset.title)
              .font(theme.typography.heroTitle)
              .foregroundStyle(theme.colors.textPrimary)
              .lineLimit(1)
              .truncationMode(.tail)

            Text(presetLine)
              .font(theme.typography.cardMeta)
              .foregroundStyle(theme.colors.textSecondary)
          }

          Spacer()

          Button(action: onStart) {
            Image(systemName: "play.fill")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(theme.colors.textInverted)
              .frame(width: 44, height: 44)
              .background(Circle().fill(theme.colors.matchPositive))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text("Start \(preset.title) on watch"))
        }

        HStack(spacing: theme.spacing.s) {
          ForEach(quickActions) { action in
            RoundedRectangle(cornerRadius: theme.components.controlCornerRadius)
              .fill(theme.colors.backgroundSecondary)
              .overlay(
                Image(systemName: action.icon)
                  .foregroundStyle(theme.colors.textSecondary)
              )
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .accessibilityLabel(Text(action.accessibilityLabel))
          }
        }
      }
    }
  }

  private var workoutGlyph: some View {
    ZStack {
      RoundedRectangle(cornerRadius: theme.components.controlCornerRadius)
        .fill(theme.colors.matchPositive.opacity(0.18))
        .frame(width: 48, height: 48)
      Image(systemName: icon(for: preset.kind))
        .font(.system(size: 24, weight: .medium))
        .foregroundStyle(theme.colors.matchPositive)
    }
  }

  private func icon(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun: return "figure.run"
    case .outdoorWalk: return "figure.walk"
    case .indoorRun: return "figure.run.circle"
    case .indoorCycle: return "bicycle"
    case .strength: return "dumbbell.fill"
    case .mobility: return "figure.cooldown"
    case .refereeDrill: return "whistle"
    case .custom: return "slider.horizontal.3"
    }
  }
}

private struct WorkoutHistoryCard: View {
  let session: WorkoutSession
  let summaryLine: String
  @Environment(\.theme) private var theme

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 96) {
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Text(session.title)
          .font(theme.typography.heroSubtitle)
          .foregroundStyle(theme.colors.textPrimary)
          .lineLimit(1)

        Text(session.kind.displayName)
          .font(theme.typography.cardMeta)
          .foregroundStyle(theme.colors.textSecondary)

        Text(summaryLine)
          .font(theme.typography.cardMeta)
          .foregroundStyle(theme.colors.textSecondary)
      }
    }
  }
}

#Preview {
  WorkoutDashboardView(services: .inMemoryStub())
    .theme(DefaultTheme())
}
