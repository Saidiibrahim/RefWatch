import SwiftUI
import _WatchKit_SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutSessionHostView: View {
  let session: WorkoutSession
  let liveMetrics: WorkoutLiveMetrics?
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
    liveMetrics: WorkoutLiveMetrics?,
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
    self.liveMetrics = liveMetrics
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
        liveMetrics: liveMetrics,
        timerModel: timerModel
      )
      .tag(WorkoutSessionTab.metrics)

      WorkoutSessionRatingPlaceholderPage()
        .tag(WorkoutSessionTab.difficultyRating)
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
  let liveMetrics: WorkoutLiveMetrics?
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout
  @Bindable private var timerModel: WorkoutTimerFaceModel
  // State to ensure time display updates periodically
  @State private var currentTime = Date()
  @State private var timeUpdateTimer: Timer?

  init(session: WorkoutSession, liveMetrics: WorkoutLiveMetrics?, timerModel: WorkoutTimerFaceModel) {
    self.session = session
    self.liveMetrics = liveMetrics
    _timerModel = Bindable(timerModel)
  }

  private var metrics: [WorkoutPrimaryMetric] {
    let energy = WorkoutMetricFormatter.activeEnergy(liveMetrics?.activeEnergy ?? session.summary.activeEnergy)
    let heartRate = WorkoutMetricFormatter.heartRate(liveMetrics?.heartRate ?? session.summary.averageHeartRate)
    let distance = WorkoutMetricFormatter.distance(liveMetrics?.totalDistance ?? session.summary.totalDistance)

    return [
      WorkoutPrimaryMetric(type: .activeEnergy, title: "Active Energy", value: energy.value, unit: energy.unit),
      WorkoutPrimaryMetric(type: .heartRate, title: "Heart Rate", value: heartRate.value, unit: heartRate.unit),
      WorkoutPrimaryMetric(type: .distance, title: "Distance", value: distance.value, unit: distance.unit)
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with glyph on left, time on right (matching Apple's design)
      HStack(alignment: .top) {
        WorkoutGlyph(kind: session.kind)
        
        Spacer()
        
        // Time at top right (Apple only shows time, no label)
        Text(currentTime, style: .time)
          .font(.system(size: layout.dimension(15, minimum: 13, maximum: 17), weight: .medium))
          .foregroundStyle(theme.colors.textPrimary)
      }
      .padding(.horizontal, layout.dimension(theme.spacing.m, minimum: theme.spacing.s))
      .padding(.top, layout.dimension(theme.spacing.m, minimum: theme.spacing.s))

      // Timer display - centered like Apple's design
      // Responsive padding: tighter on compact watches, more spacious on larger watches
      WorkoutPrimaryTimerView(timerModel: timerModel)
        .hapticsProvider(WatchHaptics())
        .frame(maxWidth: .infinity)
        .padding(.top, layout.dimension(theme.spacing.m, minimum: theme.spacing.s))

      // Metrics in Apple's order: Active Energy → Heart Rate → Distance
      // Shifted to the right to match Apple's design, with metrics left-aligned relative to each other
      HStack(alignment: .top) {
        Spacer(minLength: layout.dimension(theme.spacing.l, minimum: theme.spacing.m))
        VStack(alignment: .leading, spacing: metricSpacing) {
          ForEach(metrics) { metric in
            WorkoutPrimaryMetricView(metric: metric)
          }
        }
        // Minimal trailing spacer to allow some flexibility
        Spacer(minLength: 0)
      }
      .padding(.horizontal, layout.dimension(theme.spacing.m, minimum: theme.spacing.s))
      .padding(.top, layout.dimension(theme.spacing.m, minimum: theme.spacing.s))
      
      // Flexible spacer ensures content stays at top while allowing bottom padding
      Spacer()
    }
    .padding(.bottom, layout.safeAreaBottomPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    .onAppear {
      // Update time immediately on appear
      currentTime = Date()
      // Update time every minute to keep display current
      timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
        currentTime = Date()
      }
    }
    .onDisappear {
      // Clean up timer when view disappears
      timeUpdateTimer?.invalidate()
      timeUpdateTimer = nil
    }
  }

  // Adaptive metric spacing: tighter on compact watches to fit all content
  private var metricSpacing: CGFloat {
    switch layout.category {
    case .compact:
      // Reduced spacing for 41mm watches to ensure all metrics fit
      return layout.dimension(theme.spacing.s, minimum: theme.spacing.xs)
    case .standard, .expanded:
      // Standard spacing for larger watches
      return layout.dimension(theme.spacing.m, minimum: theme.spacing.s)
    }
  }
}

private struct WorkoutSessionControlsPage: View {
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout
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
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: theme.spacing.s) {
        controlsHeader

        LazyVGrid(columns: controlColumns, spacing: layout.dimension(theme.spacing.xs, minimum: theme.spacing.xs * 0.75)) {
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
      }
      .padding(.horizontal, theme.spacing.s)
      .padding(.top, theme.spacing.m)
      .padding(.bottom, layout.safeAreaBottomPadding)
    }
    .scrollIndicators(.visible)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private var controlColumns: [GridItem] {
    let spacing = layout.dimension(theme.spacing.xs, minimum: theme.spacing.xs * 0.75)
    return [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
  }

  private var controlsHeader: some View {
    Text(session.title)
      .font(theme.typography.cardHeadline)
      .foregroundStyle(theme.colors.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
  }

  private var tileStyle: WorkoutControlTile.Style {
    let circle = layout.dimension(44, minimum: 38)
    let icon = layout.dimension(19, minimum: 16, maximum: 24)
    let verticalSpacing = theme.spacing.xs
    var style = WorkoutControlTile.Style()
    style.circleDiameter = circle
    style.iconSize = icon
    style.titleFont = theme.typography.caption.weight(.medium)
    style.titleColor = theme.colors.textPrimary
    style.verticalSpacing = verticalSpacing
    style.tileVerticalPadding = verticalSpacing * 0.4
    style.badgeFont = theme.typography.caption.weight(.semibold)
    style.badgeHorizontalPadding = 4
    style.badgeVerticalPadding = 3
    let spacing = style.verticalSpacing ?? verticalSpacing
    let padding = style.tileVerticalPadding ?? verticalSpacing * 0.4
    style.preferredHeight = style.circleDiameter + spacing + layout.dimension(22, minimum: 18) + padding * 2
    return style
  }
}

private struct WorkoutSessionRatingPlaceholderPage: View {
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    VStack(spacing: theme.spacing.m) {
      featureGlyph
        .frame(maxWidth: .infinity, alignment: .center)

      Text("Difficulty Rating Coming Soon")
        .font(theme.typography.cardHeadline)
        .fontWeight(.semibold)
        .foregroundStyle(theme.colors.textPrimary)
        .multilineTextAlignment(.center)
      
      Spacer()
    }
    .padding(.horizontal, theme.spacing.m)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private var featureGlyph: some View {
    let diameter = layout.dimension(72, minimum: 60, maximum: 88)
    return ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: [
              theme.colors.accentSecondary.opacity(0.45),
              theme.colors.accentSecondary.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: diameter, height: diameter)

      Image(systemName: "star.fill")
        .font(.system(size: diameter * 0.45, weight: .bold))
        .foregroundStyle(theme.colors.accentSecondary)
    }
  }
}

enum WorkoutSessionTab: Hashable {
  case metrics
  case controls
  case difficultyRating
}

private enum WorkoutMetricFormatter {
  static func activeEnergy(_ kilocalories: Double?) -> (value: String, unit: String?) {
    guard let kilocalories else { return ("--", nil) }
    let kilojoules = kilocalories * 4.184
    return (kilojoules.formatted(.number.precision(.fractionLength(0))), "kJ")
  }

  static func heartRate(_ rate: Double?) -> (value: String, unit: String?) {
    guard let rate else { return ("--", nil) }
    return (Int(rate.rounded()).formatted(), "bpm")
  }

  static func distance(_ meters: Double?) -> (value: String, unit: String?) {
    guard let meters else { return ("0", "m") }
    if meters >= 1000 {
      let kilometres = meters / 1000
      return (String(format: "%.1f", kilometres), "km")
    } else {
      return (Int(meters.rounded()).formatted(), "m")
    }
  }
}

private enum WorkoutMetricType {
  case activeEnergy
  case heartRate
  case distance
}

private struct WorkoutPrimaryMetric: Identifiable {
  let id = UUID()
  let type: WorkoutMetricType
  let title: String
  let value: String
  let unit: String?
}

private struct WorkoutPrimaryMetricView: View {
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout
  let metric: WorkoutPrimaryMetric

  // Larger value font matching Apple's prominent metric display
  private var valueFont: Font {
    .system(
      size: layout.dimension(36, minimum: 30, maximum: 42),
      weight: .semibold,
      design: .rounded
    ).monospacedDigit()
  }

  // Smaller label font matching Apple's secondary text
  private var labelFont: Font {
    .system(size: layout.dimension(13, minimum: 11, maximum: 15), weight: .regular)
  }

  var body: some View {
    switch metric.type {
    case .heartRate:
      heartRateView
    case .activeEnergy:
      activeEnergyView
    case .distance:
      distanceView
    }
  }

  private var heartRateView: some View {
    HStack(alignment: .lastTextBaseline, spacing: theme.spacing.xs) {
      Text(metric.value)
        .font(valueFont)
        .foregroundStyle(theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .layoutPriority(1)

      Image(systemName: "heart.fill")
        .font(.system(size: layout.dimension(16, minimum: 14, maximum: 18), weight: .semibold))
        .foregroundStyle(.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var activeEnergyView: some View {
    HStack(alignment: .lastTextBaseline, spacing: theme.spacing.xs) {
      // Number displayed prominently (matching Apple's design)
      Text(metric.value)
        .font(valueFont)
        .foregroundStyle(theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .layoutPriority(1)

      // Label text after the number (Apple shows "1 ACTIVE KJ" format)
      if let unit = metric.unit {
        Text("ACTIVE \(unit.uppercased())")
          .font(labelFont)
          .tracking(0.3)
          .foregroundStyle(theme.colors.textSecondary.opacity(0.85))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var distanceView: some View {
    HStack(alignment: .lastTextBaseline, spacing: 0) {
      Text(metric.value)
        .font(valueFont)
        .foregroundStyle(theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .layoutPriority(1)

      if let unit = metric.unit {
        Text(unit.uppercased())
          .font(labelFont)
          .tracking(0.3)
          .foregroundStyle(theme.colors.textSecondary.opacity(0.85))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct WorkoutPrimaryTimerView: View {
  @Environment(\.theme) private var theme
  @Environment(\.haptics) private var haptics
  @Environment(\.watchLayoutScale) private var layout
  @Bindable var timerModel: WorkoutTimerFaceModel

  init(timerModel: WorkoutTimerFaceModel) {
    _timerModel = Bindable(timerModel)
  }

  // Yellow color matching Apple's workout timer
  private var timerYellow: Color {
    Color(red: 1.0, green: 0.84, blue: 0.0) // Bright yellow similar to Apple's
  }

  private var timerFont: Font {
    .system(
      size: layout.dimension(46, minimum: 42, maximum: 54),
      weight: .bold,
      design: .rounded
    ).monospacedDigit()
  }

  var body: some View {
    // Center the timer text (matching Apple's design)
    HStack {
      Spacer()
      Text(timerModel.matchTime)
        .font(timerFont)
        .tracking(-0.2)
        .foregroundStyle(timerModel.isPaused ? theme.colors.textSecondary : timerYellow)
      Spacer()
    }
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
  @Environment(\.watchLayoutScale) private var layout
  let kind: WorkoutKind

  // Green color matching Apple's workout app glyph background
  private var greenBackground: Color {
    Color(red: 0.2, green: 0.8, blue: 0.4) // Bright green similar to Apple's
  }

  var body: some View {
    Circle()
      .fill(greenBackground)
      .frame(width: glyphDiameter, height: glyphDiameter)
      .overlay(
        Image(systemName: iconName)
          .font(.system(size: iconSize, weight: .semibold))
          .foregroundStyle(.white)
      )
  }

  private var glyphDiameter: CGFloat {
    layout.dimension(44, minimum: 40, maximum: 48)
  }

  private var iconSize: CGFloat {
    layout.dimension(20, minimum: 18, maximum: 22)
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

#Preview("Workout Session – Metrics 41mm") {
  WorkoutSessionHostView(
    session: WorkoutSessionPreviewData.active,
    liveMetrics: WorkoutSessionPreviewData.liveMetrics,
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
  .watchLayoutScale(WatchLayoutScale(category: .compact))
  .previewDevice("Apple Watch Series 9 (41mm)")
}

#Preview("Workout Session – Paused 45mm") {
  WorkoutSessionHostView(
    session: WorkoutSessionPreviewData.active,
    liveMetrics: WorkoutSessionPreviewData.liveMetrics,
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
  .watchLayoutScale(WatchLayoutScale(category: .standard))
  .previewDevice("Apple Watch Series 9 (45mm)")
}

#Preview("Workout Session – Rating Ultra") {
  WorkoutSessionHostView(
    session: WorkoutSessionPreviewData.active,
    liveMetrics: WorkoutSessionPreviewData.liveMetrics,
    isPaused: false,
    isEnding: false,
    isRecordingSegment: false,
    lapCount: 1,
    initialTab: .difficultyRating,
    onPause: {},
    onResume: {},
    onEnd: {},
    onMarkSegment: {},
    onRequestNewSession: {}
  )
  .theme(DefaultTheme())
  .watchLayoutScale(WatchLayoutScale(category: .expanded))
  .previewDevice("Apple Watch Ultra 2 (49mm)")
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
      activeEnergy: 310,
      duration: 1_200
    ),
    presetId: UUID()
  )

  static let liveMetrics = WorkoutLiveMetrics(
    sessionId: active.id,
    elapsedTime: 1_260,
    totalDistance: 4_580,
    activeEnergy: 328,
    heartRate: 138
  )
}
