import SwiftUI
import MediaPlayer
import _WatchKit_SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutSessionHostView: View {
  let session: WorkoutSession
  let isPaused: Bool
  let isEnding: Bool
  let isRecordingSegment: Bool
  let lapCount: Int
  let onPause: () -> Void
  let onResume: () -> Void
  let onEnd: () -> Void
  let onMarkSegment: () -> Void
  let onRequestNewSession: () -> Void

  @State private var timerModel: WorkoutTimerFaceModel
  @State private var tabSelection: WorkoutSessionTab = .metrics
  @State private var showShareComingSoon = false
  @Environment(\.theme) private var theme

  init(
    session: WorkoutSession,
    isPaused: Bool,
    isEnding: Bool,
    isRecordingSegment: Bool,
    lapCount: Int,
    initialTab: WorkoutSessionTab = .metrics,
    onPause: @escaping () -> Void,
    onResume: @escaping () -> Void,
    onEnd: @escaping () -> Void,
    onMarkSegment: @escaping () -> Void,
    onRequestNewSession: @escaping () -> Void
  ) {
    self.session = session
    self.isPaused = isPaused
    self.isEnding = isEnding
    self.isRecordingSegment = isRecordingSegment
    self.lapCount = lapCount
    self.onPause = onPause
    self.onResume = onResume
    self.onEnd = onEnd
    self.onMarkSegment = onMarkSegment
    self.onRequestNewSession = onRequestNewSession
    _timerModel = State(initialValue: WorkoutTimerFaceModel(session: session, onPause: onPause, onResume: onResume))
    _tabSelection = State(initialValue: initialTab)
  }

  var body: some View {
    TabView(selection: $tabSelection) {
      WorkoutSessionControlsPage(
        session: session,
        timerModel: timerModel,
        isPaused: isPaused,
        isEnding: isEnding,
        isRecordingSegment: isRecordingSegment,
        lapCount: lapCount,
        onMarkSegment: onMarkSegment,
        onEnd: onEnd,
        onRequestNewSession: onRequestNewSession,
        onShare: { showShareComingSoon = true }
      )
      .tag(WorkoutSessionTab.controls)

      WorkoutSessionMainPage(
        session: session,
        metrics: primaryMetrics,
        timerModel: timerModel
      )
      .tag(WorkoutSessionTab.metrics)

      WorkoutSessionMediaPage(kind: session.kind)
        .tag(WorkoutSessionTab.media)
    }
    .tabViewStyle(.page(indexDisplayMode: .automatic))
    .indexViewStyle(.page)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    .onAppear {
      timerModel.updatePauseState(isPaused)
    }
    .onChange(of: session) { newValue in
      timerModel.updateSession(newValue)
    }
    .onChange(of: isPaused) { paused in
      timerModel.updatePauseState(paused)
    }
    .alert("Coming Soon", isPresented: $showShareComingSoon) {
      Button("OK", role: .cancel) {
        showShareComingSoon = false
      }
    } message: {
      Text("Sharing workouts is coming soon.")
    }
  }
}

private struct WorkoutSessionMainPage: View {
  let session: WorkoutSession
  let metrics: [WorkoutPrimaryMetric]
  @Environment(\.theme) private var theme
  @Bindable private var timerModel: WorkoutTimerFaceModel

  init(session: WorkoutSession, metrics: [WorkoutPrimaryMetric], timerModel: WorkoutTimerFaceModel) {
    self.session = session
    self.metrics = metrics
    _timerModel = Bindable(timerModel)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      HStack(alignment: .center, spacing: theme.spacing.xs) {
        WorkoutGlyph(kind: session.kind)

        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(session.title)
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

          Text(session.kind.displayName.uppercased())
            .font(theme.typography.label)
            .foregroundStyle(theme.colors.textSecondary)
        }

        Spacer(minLength: theme.spacing.xs)

        Text(timerModel.isPaused ? "Paused" : "Active")
          .font(theme.typography.label)
          .foregroundStyle(timerModel.isPaused ? theme.colors.matchWarning : theme.colors.accentSecondary)
      }

      WorkoutPrimaryTimerView(timerModel: timerModel)
        .hapticsProvider(WatchHaptics())

      VStack(spacing: theme.spacing.xs) {
        ForEach(metrics) { metric in
          WorkoutPrimaryMetricView(metric: metric)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, theme.spacing.s)
    .padding(.top, theme.spacing.s)
    .padding(.bottom, theme.spacing.xs)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
  }
}

private struct WorkoutSessionControlsPage: View {
  @Environment(\.theme) private var theme
  @Bindable private var timerModel: WorkoutTimerFaceModel
  let session: WorkoutSession
  let isPaused: Bool
  let isEnding: Bool
  let isRecordingSegment: Bool
  let lapCount: Int
  let onMarkSegment: () -> Void
  let onEnd: () -> Void
  let onRequestNewSession: () -> Void
  let onShare: () -> Void

  init(
    session: WorkoutSession,
    timerModel: WorkoutTimerFaceModel,
    isPaused: Bool,
    isEnding: Bool,
    isRecordingSegment: Bool,
    lapCount: Int,
    onMarkSegment: @escaping () -> Void,
    onEnd: @escaping () -> Void,
    onRequestNewSession: @escaping () -> Void,
    onShare: @escaping () -> Void
  ) {
    self.session = session
    _timerModel = Bindable(timerModel)
    self.isPaused = isPaused
    self.isEnding = isEnding
    self.isRecordingSegment = isRecordingSegment
    self.lapCount = lapCount
    self.onMarkSegment = onMarkSegment
    self.onEnd = onEnd
    self.onRequestNewSession = onRequestNewSession
    self.onShare = onShare
  }

  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      controlsHeader

      LazyVGrid(columns: controlColumns, spacing: theme.spacing.xs) {
        WorkoutControlTile(
          title: isPaused ? "Resume" : "Pause",
          systemImage: isPaused ? "play.fill" : "pause.fill",
          tint: theme.colors.matchWarning,
          foreground: theme.colors.backgroundPrimary,
          isDisabled: isEnding,
          style: tileStyle,
          action: {
            if isPaused {
              timerModel.resumeMatch()
            } else {
              timerModel.pauseMatch()
            }
          }
        )

        WorkoutControlTile(
          title: "Segment",
          systemImage: "flag.checkered",
          tint: theme.colors.matchPositive,
          foreground: theme.colors.backgroundPrimary,
          badgeText: lapCount > 0 ? "\(lapCount)" : nil,
          isDisabled: isEnding || isRecordingSegment,
          isLoading: isRecordingSegment,
          style: tileStyle,
          action: onMarkSegment
        )

        WorkoutControlTile(
          title: "End",
          systemImage: "xmark",
          tint: theme.colors.matchCritical,
          foreground: theme.colors.backgroundPrimary,
          isDisabled: isEnding,
          style: tileStyle,
          action: onEnd
        )

        WorkoutControlTile(
          title: "New",
          systemImage: "plus",
          tint: theme.colors.accentSecondary,
          foreground: theme.colors.backgroundPrimary,
          isDisabled: isEnding,
          style: tileStyle,
          action: onRequestNewSession
        )

        WorkoutControlTile(
          title: "Share",
          systemImage: "square.and.arrow.up",
          tint: theme.colors.accentPrimary,
          foreground: theme.colors.backgroundPrimary,
          isDisabled: isEnding,
          style: tileStyle,
          action: onShare
        )

        WorkoutControlTilePlaceholder(style: tileStyle)
      }

      Spacer()
    }
    .padding(.horizontal, theme.spacing.s)
    .padding(.top, theme.spacing.m)
    .padding(.bottom, theme.spacing.xs)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private var controlColumns: [GridItem] {
    [GridItem(.flexible(), spacing: theme.spacing.xs), GridItem(.flexible(), spacing: theme.spacing.xs)]
  }

  private var controlsHeader: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Text(session.title)
        .font(theme.typography.cardHeadline)
        .foregroundStyle(theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(timerModel.isPaused ? "Workout paused" : "Workout active")
        .font(theme.typography.cardMeta)
        .foregroundStyle(timerModel.isPaused ? theme.colors.matchWarning : theme.colors.textSecondary)
    }
  }

  private var tileStyle: WorkoutControlTile.Style {
    var style = WorkoutControlTile.Style()
    style.circleDiameter = 44
    style.iconSize = 19
    style.titleFont = .system(size: 13, weight: .medium, design: .rounded)
    style.titleColor = theme.colors.textPrimary
    style.verticalSpacing = theme.spacing.xs
    style.tileVerticalPadding = theme.spacing.xs * 0.3
    style.badgeFont = .system(size: 11, weight: .semibold, design: .rounded)
    style.badgeHorizontalPadding = 4
    style.badgeVerticalPadding = 3
    style.preferredHeight = style.circleDiameter + (style.verticalSpacing ?? theme.spacing.xs) + 24 + (style.tileVerticalPadding ?? theme.spacing.xs * 0.3) * 2
    return style
  }
}

private struct WorkoutSessionMediaPage: View {
  @Environment(\.theme) private var theme
  @Environment(\.scenePhase) private var scenePhase
  let kind: WorkoutKind

  @State private var viewModelReference: WorkoutSessionMediaViewModel
  @Bindable private var viewModel: WorkoutSessionMediaViewModel
  private let haptics = WatchHaptics()

  init(kind: WorkoutKind) {
    self.kind = kind
    let model = WorkoutSessionMediaViewModel()
    _viewModelReference = State(initialValue: model)
    _viewModel = Bindable(model)
  }

  var body: some View {
    Group {
      if #available(watchOS 10.0, *) {
        content
      } else {
        legacyFallback
      }
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.top, theme.spacing.l)
    .padding(.bottom, theme.spacing.m)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    .onAppear { viewModelReference.activate() }
    .onDisappear { viewModelReference.deactivate() }
    .onChange(of: scenePhase) { phase in
      guard phase == .active else { return }
      viewModelReference.refresh()
    }
  }

  @ViewBuilder
  private var content: some View {
    VStack(spacing: theme.spacing.m) {
      header

      artworkTile
        .frame(maxWidth: .infinity)

      labels

      Spacer(minLength: theme.spacing.l)

      transportControls
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var legacyFallback: some View {
    VStack(spacing: theme.spacing.s) {
      Image(systemName: "music.note")
        .font(.system(size: 40))
        .foregroundStyle(theme.colors.accentSecondary)

      Text("Requires watchOS 10 or later")
        .font(theme.typography.cardMeta)
        .foregroundStyle(theme.colors.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  private var header: some View {
    HStack {
      Spacer()

      routeIndicator
    }
  }

  private var routeIndicator: some View {
    let background = viewModel.isUsingExternalRoute ? theme.colors.accentPrimary.opacity(0.16) : theme.colors.backgroundElevated
    let foreground = viewModel.isUsingExternalRoute ? theme.colors.accentPrimary : theme.colors.textSecondary

    return VStack {
      Image(systemName: viewModel.routeGlyphName)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(foreground)
        .padding(10)
        .background(
          Circle()
            .fill(background)
        )
    }
    .accessibilityLabel(Text(viewModel.routeDescription))
  }

  private var artworkTile: some View {
    let cornerRadius: CGFloat = 22
    let size: CGFloat = 120

    return ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(LinearGradient(colors: [theme.colors.backgroundElevated, theme.colors.backgroundElevated.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(theme.colors.surfaceOverlay, lineWidth: 1)
        )

#if canImport(UIKit)
      if let artwork = viewModel.artworkImage {
        Image(uiImage: artwork)
          .resizable()
          .scaledToFill()
          .frame(width: size, height: size)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      } else {
        placeholderIcon(size: size)
      }
#else
      placeholderIcon(size: size)
#endif
    }
    .frame(width: size, height: size)
  }

  @ViewBuilder
  private func placeholderIcon(size: CGFloat) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(theme.colors.backgroundElevated.opacity(0.6))

      Image(systemName: "applewatch")
        .font(.system(size: size * 0.32, weight: .medium))
        .foregroundStyle(theme.colors.accentSecondary)
    }
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var labels: some View {
    VStack(spacing: theme.spacing.xs) {
      Text(viewModel.title)
        .font(.system(size: 20, weight: .semibold, design: .rounded))
        .foregroundStyle(theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(viewModel.controlsAvailable ? viewModel.subtitle : "Connect to iPhone to control Music")
        .font(theme.typography.cardMeta)
        .foregroundStyle(theme.colors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
  }

  private var transportControls: some View {
    HStack(spacing: theme.spacing.l) {
      transportButton(
        systemName: "backward.fill",
        diameter: 44,
        isDisabled: !viewModel.controlsAvailable || !viewModel.canSkipBackward,
        action: {
          haptics.play(.tap)
          viewModelReference.skipBackward()
        }
      )

      transportButton(
        systemName: viewModel.isPlaying ? "pause.fill" : "play.fill",
        diameter: 56,
        isDisabled: !viewModel.controlsAvailable,
        tint: theme.colors.accentPrimary,
        foreground: theme.colors.textInverted,
        action: {
          haptics.play(viewModel.isPlaying ? .pause : .resume)
          viewModelReference.togglePlayPause()
        }
      )

      transportButton(
        systemName: "forward.fill",
        diameter: 44,
        isDisabled: !viewModel.controlsAvailable || !viewModel.canSkipForward,
        action: {
          haptics.play(.tap)
          viewModelReference.skipForward()
        }
      )
    }
  }

  private func transportButton(
    systemName: String,
    diameter: CGFloat,
    isDisabled: Bool,
    tint: Color? = nil,
    foreground: Color? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: diameter * 0.34, weight: .semibold))
        .frame(width: diameter, height: diameter)
        .foregroundStyle(foreground ?? theme.colors.textPrimary)
        .background(
          Circle()
            .fill(tint ?? theme.colors.backgroundElevated)
        )
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.4 : 1)
    .accessibilityLabel(accessibilityLabel(for: systemName))
  }

  private func accessibilityLabel(for systemName: String) -> Text {
    switch systemName {
    case "backward.fill":
      return Text("Skip backward")
    case "forward.fill":
      return Text("Skip forward")
    case "play.fill":
      return Text("Play")
    case "pause.fill":
      return Text("Pause")
    default:
      return Text(systemName)
    }
  }
}

enum WorkoutSessionTab: Hashable {
  case metrics
  case controls
  case media
}

private extension WorkoutSessionHostView {
  var primaryMetrics: [WorkoutPrimaryMetric] {
    let energy = formattedActiveEnergy(session.summary.activeEnergy)
    let heartRate = formattedHeartRate(session.summary.averageHeartRate)
    let distance = formattedDistance(session.summary.totalDistance)

    return [
      WorkoutPrimaryMetric(title: "Active Energy", value: energy.value, unit: energy.unit),
      WorkoutPrimaryMetric(title: "Heart Rate", value: heartRate.value, unit: heartRate.unit),
      WorkoutPrimaryMetric(title: "Distance", value: distance.value, unit: distance.unit)
    ]
  }

  func formattedActiveEnergy(_ kilocalories: Double?) -> (value: String, unit: String?) {
    guard let kilocalories else { return ("--", nil) }
    let kilojoules = kilocalories * 4.184
    return (kilojoules.formatted(.number.precision(.fractionLength(0))), "kJ")
  }

  func formattedHeartRate(_ rate: Double?) -> (value: String, unit: String?) {
    guard let rate else { return ("--", nil) }
    return (Int(rate.rounded()).formatted(), "bpm")
  }

  func formattedDistance(_ meters: Double?) -> (value: String, unit: String?) {
    guard let meters else { return ("--", nil) }
    if meters >= 1000 {
      let kilometres = meters / 1000
      return (String(format: "%.1f", kilometres), "km")
    } else {
      return (Int(meters.rounded()).formatted(), "m")
    }
  }
}

private struct WorkoutPrimaryMetric: Identifiable {
  let id = UUID()
  let title: String
  let value: String
  let unit: String?
}

private struct WorkoutPrimaryMetricView: View {
  @Environment(\.theme) private var theme
  let metric: WorkoutPrimaryMetric

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: theme.spacing.xs) {
      HStack(alignment: .lastTextBaseline, spacing: theme.spacing.xs) {
        Text(metric.value)
          .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
          .foregroundStyle(theme.colors.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .layoutPriority(1)

        if let unit = metric.unit {
          Text(unit.uppercased())
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
      }

      Spacer()

      Text(metric.title.uppercased())
        .font(theme.typography.cardMeta)
        .foregroundStyle(theme.colors.textSecondary)
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
  }
}

private struct WorkoutPrimaryTimerView: View {
  @Environment(\.theme) private var theme
  @Environment(\.haptics) private var haptics
  @Bindable var timerModel: WorkoutTimerFaceModel

  init(timerModel: WorkoutTimerFaceModel) {
    _timerModel = Bindable(timerModel)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Text(timerModel.matchTime)
        .font(theme.typography.timerPrimary)
        .foregroundStyle(timerModel.isPaused ? theme.colors.textSecondary : theme.colors.accentSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, theme.spacing.s)
    .contentShape(Rectangle())
    .onTapGesture {
      haptics.play(.tap)
      if timerModel.isPaused {
        timerModel.resumeMatch()
      } else {
        timerModel.pauseMatch()
      }
    }
  }
}

private struct WorkoutGlyph: View {
  @Environment(\.theme) private var theme
  let kind: WorkoutKind

  var body: some View {
    Circle()
      .fill(theme.colors.backgroundSecondary)
      .frame(width: 48, height: 48)
      .overlay(
        Image(systemName: iconName)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(theme.colors.accentSecondary)
      )
  }

  private var iconName: String {
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
}

#Preview("Workout Session") {
  WorkoutSessionHostView(
    session: WorkoutSessionPreviewData.active,
    isPaused: false,
    isEnding: false,
    isRecordingSegment: false,
    lapCount: 2,
    initialTab: .metrics,
    onPause: {},
    onResume: {},
    onEnd: {},
    onMarkSegment: {},
    onRequestNewSession: {}
  )
  .theme(DefaultTheme())
}

#Preview("Workout Session – Paused") {
  WorkoutSessionHostView(
    session: WorkoutSessionPreviewData.active,
    isPaused: true,
    isEnding: false,
    isRecordingSegment: false,
    lapCount: 0,
    initialTab: .controls,
    onPause: {},
    onResume: {},
    onEnd: {},
    onMarkSegment: {},
    onRequestNewSession: {}
  )
  .theme(DefaultTheme())
}

#Preview("Workout Session – Media") {
  WorkoutSessionHostView(
    session: WorkoutSessionPreviewData.active,
    isPaused: false,
    isEnding: false,
    isRecordingSegment: false,
    lapCount: 1,
    initialTab: .media,
    onPause: {},
    onResume: {},
    onEnd: {},
    onMarkSegment: {},
    onRequestNewSession: {}
  )
  .theme(DefaultTheme())
}

private enum WorkoutSessionPreviewData {
  static let segments: [WorkoutSegment] = [
    WorkoutSegment(name: "Warm-up", purpose: .warmup, plannedDuration: 300, plannedDistance: 0.4),
    WorkoutSegment(name: "Tempo", purpose: .work, plannedDuration: 900, plannedDistance: 2.4,
                   target: .init(intensityZone: .tempo)),
    WorkoutSegment(name: "Cooldown", purpose: .cooldown, plannedDuration: 300, plannedDistance: 0.6)
  ]

  static let active: WorkoutSession = .init(
    state: .active,
    kind: .outdoorRun,
    title: "Outdoor Run",
    startedAt: Date().addingTimeInterval(-1_200),
    segments: segments,
    summary: .init(
      averageHeartRate: 134,
      maximumHeartRate: 168,
      totalDistance: 4_200,
      duration: 1_200
    ),
    presetId: UUID()
  )
}
