import RefWatchCore
import RefWorkoutCore
import SwiftUI

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
        LazyVStack(spacing: self.theme.spacing.stackSpacing, pinnedViews: []) {
          if self.viewModel.authorization.state != .authorized {
            authorizationCard
          }

          overviewCard

          presetsSection

          historySection
        }
        .padding(.vertical, self.theme.spacing.l)
        .padding(.horizontal, self.theme.spacing.l)
      }
      .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Workout")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button { self.viewModel.reloadPresets() } label: {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
      .refreshable {
        await self.viewModel.refresh()
      }
    }
    .onAppear {
      guard !self.didLoad else { return }
      self.didLoad = true
      self.viewModel.load()
    }
    .onChange(of: self.viewModel.errorMessage) { _, message in
      self.showError = message != nil
    }
    .alert("Workout Error", isPresented: self.$showError) {
      Button("OK", role: .cancel) {
        self.viewModel.errorMessage = nil
      }
    } message: {
      Text(self.viewModel.errorMessage ?? "An unexpected error occurred.")
    }
    .alert("Start on Your Watch", isPresented: self.$showStartReminder) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Launch \(self.selectedPresetTitle) from RefWatch on Apple Watch to capture live metrics.")
    }
  }
}

extension WorkoutDashboardView {
  private var authorizationCard: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(alignment: .leading, spacing: self.theme.spacing.s) {
        Text(self.authorizationMessage)
          .font(self.theme.typography.cardMeta)
          .foregroundStyle(self.theme.colors.textSecondary)

        Button(action: self.viewModel.requestAuthorization) {
          Text(self.viewModel.authorization.state == .notDetermined ? "Grant Health Access" : "Review Health Access")
            .font(self.theme.typography.button)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(self.theme.colors.accentSecondary)
      }
    }
  }

  private var overviewCard: some View {
    ThemeCardContainer(role: .secondary) {
      VStack(alignment: .leading, spacing: self.theme.spacing.m) {
        Text("Overview")
          .font(self.theme.typography.heroSubtitle)
          .foregroundStyle(self.theme.colors.textPrimary)

        HStack(spacing: self.theme.spacing.l) {
          self.statBlock(title: "Presets", value: "\(self.viewModel.presets.count)")
          Divider()
            .background(self.theme.colors.outlineMuted)
          self.statBlock(title: "Recent Sessions", value: "\(self.viewModel.recentSessions.count)")
        }

        Text(
          "Start workouts on your Apple Watch to capture real-time metrics. " +
            "Presets and history stay in sync once connectivity is established.")
          .font(self.theme.typography.cardMeta)
          .foregroundStyle(self.theme.colors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var presetsSection: some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.s) {
      self.sectionHeader("Presets")

      if self.viewModel.presets.isEmpty {
        ThemeCardContainer(role: .secondary) {
          Text("Create your first workout preset to build repeatable training sessions.")
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
      } else {
        ForEach(self.viewModel.presets) { preset in
          NavigationLink {
            Text("Preset detail for \(preset.title) coming soon.")
              .padding()
              .navigationTitle(preset.title)
          } label: {
            WorkoutPresetCard(
              preset: preset,
              presetLine: self.presetLine(preset),
              onStart: {
                self.selectedPresetTitle = preset.title
                self.showStartReminder = true
              })
          }
          .buttonStyle(.plain)
        }
      }

      Button {
        // Placeholder for preset creation flow
      } label: {
        ThemeCardContainer(role: .primary, minHeight: 72) {
          HStack(spacing: self.theme.spacing.m) {
            Image(systemName: "plus.circle.fill")
              .font(self.theme.typography.iconAccent)
              .foregroundStyle(self.theme.colors.textPrimary)
            VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
              Text("New Preset")
                .font(self.theme.typography.heroSubtitle)
                .foregroundStyle(self.theme.colors.textPrimary)
              Text("Design referee-specific drills and repeats from here.")
                .font(self.theme.typography.cardMeta)
                .foregroundStyle(self.theme.colors.textPrimary.opacity(0.8))
            }
            Spacer()
          }
        }
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var historySection: some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.s) {
      self.sectionHeader("Recent Sessions")

      if self.viewModel.recentSessions.isEmpty {
        ThemeCardContainer(role: .secondary) {
          Text("Completed workouts will appear here once synced from the watch.")
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
      } else {
        ForEach(self.viewModel.recentSessions) { session in
          NavigationLink {
            Text("Session detail for \(session.title) coming soon.")
              .padding()
              .navigationTitle(session.title)
          } label: {
            WorkoutHistoryCard(
              session: session,
              summaryLine: self.sessionLine(session))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func statBlock(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
      Text(title)
        .font(self.theme.typography.cardMeta)
        .foregroundStyle(self.theme.colors.textSecondary)
      Text(value)
        .font(self.theme.typography.heroTitle)
        .foregroundStyle(self.theme.colors.textPrimary)
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(self.theme.typography.heroSubtitle)
      .foregroundStyle(self.theme.colors.textPrimary)
      .padding(.horizontal, self.theme.spacing.xs)
  }

  private var authorizationMessage: String {
    switch self.viewModel.authorization.state {
    case .notDetermined:
      "RefWatch needs permission to read workouts, heart rate, and distance from Health to power the dashboard."
    case .denied:
      "Health access is currently denied. Update permissions in the Health app to sync workouts."
    case .limited:
      "Health access is limited. Allow all metrics for richer insights."
    case .authorized:
      ""
    }
  }

  fileprivate func presetLine(_ preset: WorkoutPreset) -> String {
    var parts: [String] = []
    let duration = preset.totalPlannedDuration
    if duration > 0 {
      parts.append(self.formatDuration(duration))
    }
    let distance = preset.totalPlannedDistance
    if distance > 0 {
      parts.append(self.formatDistance(distance))
    }
    parts.append(preset.kind.displayName)
    return parts.joined(separator: " • ")
  }

  private func sessionLine(_ session: WorkoutSession) -> String {
    var parts: [String] = []
    if let duration = session.totalDuration ?? session.summary.duration {
      parts.append(self.formatDuration(duration))
    }
    if let distance = session.summary.totalDistance {
      parts.append(self.formatDistance(distance))
    }
    if let completed = session.endedAt {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .short
      parts.append(formatter.localizedString(for: completed, relativeTo: Date()))
    }
    return parts.joined(separator: " • ")
  }

  private func formatDuration(_ interval: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter.string(from: interval) ?? "0m"
  }

  private func formatDistance(_ meters: Double) -> String {
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
    ThemeCardSurfaceStyle(
      background: theme.colors.accentPrimary,
      outline: nil,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textPrimary.opacity(0.84))
  case .secondary:
    ThemeCardSurfaceStyle(
      background: theme.colors.backgroundElevated,
      outline: theme.colors.outlineMuted,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textSecondary)
  case .positive:
    ThemeCardSurfaceStyle(
      background: theme.colors.matchPositive,
      outline: nil,
      titleColor: Color.white,
      subtitleColor: Color.white.opacity(0.85))
  case .destructive:
    ThemeCardSurfaceStyle(
      background: theme.colors.matchCritical,
      outline: nil,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textPrimary.opacity(0.84))
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

    self.content
      .padding(.vertical, self.theme.spacing.m)
      .padding(.horizontal, self.theme.components.cardHorizontalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(minHeight: self.minHeight, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
          .fill(styling.background)
          .overlay(
            RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
              .stroke(styling.outline ?? .clear, lineWidth: styling.outline == nil ? 0 : 1)))
      .shadow(
        color: Color.black.opacity(self.theme.components.cardShadowOpacity),
        radius: self.theme.components.cardShadowRadius,
        x: 0,
        y: self.theme.components.cardShadowYOffset)
      .contentShape(RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous))
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
      QuickAction(icon: "clock.arrow.circlepath", accessibilityLabel: "Repeat intervals"),
    ]
  }

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 120) {
      VStack(alignment: .leading, spacing: self.theme.spacing.m) {
        HStack(alignment: .top, spacing: self.theme.spacing.m) {
          self.workoutGlyph

          VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
            Text(self.preset.title)
              .font(self.theme.typography.heroTitle)
              .foregroundStyle(self.theme.colors.textPrimary)
              .lineLimit(1)
              .truncationMode(.tail)

            Text(self.presetLine)
              .font(self.theme.typography.cardMeta)
              .foregroundStyle(self.theme.colors.textSecondary)
          }

          Spacer()

          Button(action: self.onStart) {
            Image(systemName: "play.fill")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(self.theme.colors.textInverted)
              .frame(width: 44, height: 44)
              .background(Circle().fill(self.theme.colors.matchPositive))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text("Start \(self.preset.title) on watch"))
        }

        HStack(spacing: self.theme.spacing.s) {
          ForEach(self.quickActions) { action in
            RoundedRectangle(cornerRadius: self.theme.components.controlCornerRadius)
              .fill(self.theme.colors.backgroundSecondary)
              .overlay(
                Image(systemName: action.icon)
                  .foregroundStyle(self.theme.colors.textSecondary))
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
      RoundedRectangle(cornerRadius: self.theme.components.controlCornerRadius)
        .fill(self.theme.colors.matchPositive.opacity(0.18))
        .frame(width: 48, height: 48)
      Image(systemName: self.icon(for: self.preset.kind))
        .font(.system(size: 24, weight: .medium))
        .foregroundStyle(self.theme.colors.matchPositive)
    }
  }

  private func icon(for kind: WorkoutKind) -> String {
    switch kind {
    case .outdoorRun: "figure.run"
    case .outdoorWalk: "figure.walk"
    case .indoorRun: "figure.run.circle"
    case .indoorCycle: "bicycle"
    case .strength: "dumbbell.fill"
    case .mobility: "figure.cooldown"
    case .refereeDrill: "whistle"
    case .custom: "slider.horizontal.3"
    }
  }
}

private struct WorkoutHistoryCard: View {
  let session: WorkoutSession
  let summaryLine: String
  @Environment(\.theme) private var theme

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 96) {
      VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
        Text(self.session.title)
          .font(self.theme.typography.heroSubtitle)
          .foregroundStyle(self.theme.colors.textPrimary)
          .lineLimit(1)

        Text(self.session.kind.displayName)
          .font(self.theme.typography.cardMeta)
          .foregroundStyle(self.theme.colors.textSecondary)

        Text(self.summaryLine)
          .font(self.theme.typography.cardMeta)
          .foregroundStyle(self.theme.colors.textSecondary)
      }
    }
  }
}

#Preview {
  WorkoutDashboardView(services: .inMemoryStub())
    .theme(DefaultTheme())
}
