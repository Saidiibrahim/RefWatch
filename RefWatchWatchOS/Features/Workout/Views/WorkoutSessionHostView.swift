import _WatchKit_SwiftUI
import RefWatchCore
import RefWorkoutCore
import SwiftUI

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
    onRequestNewSession: @escaping () -> Void)
  {
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
    TabView(selection: self.$tabSelection) {
      WorkoutSessionControlsPage(
        session: self.session,
        timerModel: self.timerModel,
        isPaused: self.isPaused,
        isEnding: self.isEnding,
        isRecordingSegment: self.isRecordingSegment,
        lapCount: self.lapCount,
        onMarkSegment: self.onMarkSegment,
        onEnd: self.onEnd,
        onRequestNewSession: self.onRequestNewSession,
        onShare: { self.showShareComingSoon = true })
        .tag(WorkoutSessionTab.controls)

      WorkoutSessionMainPage(
        session: self.session,
        liveMetrics: self.liveMetrics,
        timerModel: self.timerModel)
        .tag(WorkoutSessionTab.metrics)

      WorkoutSessionRatingPlaceholderPage()
        .tag(WorkoutSessionTab.difficultyRating)
    }
    .tabViewStyle(.page(indexDisplayMode: .automatic))
    .indexViewStyle(.page)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .onAppear {
      self.timerModel.updatePauseState(self.isPaused)
    }
    .onChange(of: self.session) { _, newValue in
      self.timerModel.updateSession(newValue)
    }
    .onChange(of: self.isPaused) { _, paused in
      self.timerModel.updatePauseState(paused)
    }
    .alert("Coming Soon", isPresented: self.$showShareComingSoon) {
      Button("OK", role: .cancel) {
        self.showShareComingSoon = false
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
    let energy = WorkoutMetricFormatter
      .activeEnergy(self.liveMetrics?.activeEnergy ?? self.session.summary.activeEnergy)
    let heartRate = WorkoutMetricFormatter
      .heartRate(self.liveMetrics?.heartRate ?? self.session.summary.averageHeartRate)
    let distance = WorkoutMetricFormatter
      .distance(self.liveMetrics?.totalDistance ?? self.session.summary.totalDistance)

    return [
      WorkoutPrimaryMetric(type: .activeEnergy, title: "Active Energy", value: energy.value, unit: energy.unit),
      WorkoutPrimaryMetric(type: .heartRate, title: "Heart Rate", value: heartRate.value, unit: heartRate.unit),
      WorkoutPrimaryMetric(type: .distance, title: "Distance", value: distance.value, unit: distance.unit),
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with glyph on left, time on right (matching Apple's design)
      HStack(alignment: .top) {
        WorkoutGlyph(kind: self.session.kind)

        Spacer()

        // Time at top right (Apple only shows time, no label)
        Text(self.currentTime, style: .time)
          .font(.system(size: self.layout.dimension(15, minimum: 13, maximum: 17), weight: .medium))
          .foregroundStyle(self.theme.colors.textPrimary)
      }
      .padding(.horizontal, self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s))
      .padding(.top, self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s))

      // Timer display - centered like Apple's design
      // Responsive padding: tighter on compact watches, more spacious on larger watches
      WorkoutPrimaryTimerView(timerModel: self.timerModel)
        .hapticsProvider(WatchHaptics())
        .frame(maxWidth: .infinity)
        .padding(.top, self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s))

      // Metrics in Apple's order: Active Energy → Heart Rate → Distance
      // Shifted to the right to match Apple's design, with metrics left-aligned relative to each other
      HStack(alignment: .top) {
        Spacer(minLength: self.layout.dimension(self.theme.spacing.l, minimum: self.theme.spacing.m))
        VStack(alignment: .leading, spacing: self.metricSpacing) {
          ForEach(self.metrics) { metric in
            WorkoutPrimaryMetricView(metric: metric)
          }
        }
        // Minimal trailing spacer to allow some flexibility
        Spacer(minLength: 0)
      }
      .padding(.horizontal, self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s))
      .padding(.top, self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s))

      // Flexible spacer ensures content stays at top while allowing bottom padding
      Spacer()
    }
    .padding(.bottom, self.layout.safeAreaBottomPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .onAppear {
      // Update time immediately on appear
      self.currentTime = Date()
      // Update time every minute to keep display current
      self.timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
        self.currentTime = Date()
      }
    }
    .onDisappear {
      // Clean up timer when view disappears
      self.timeUpdateTimer?.invalidate()
      self.timeUpdateTimer = nil
    }
  }

  // Adaptive metric spacing: tighter on compact watches to fit all content
  private var metricSpacing: CGFloat {
    switch self.layout.category {
    case .compact:
      // Reduced spacing for 41mm watches to ensure all metrics fit
      self.layout.dimension(self.theme.spacing.s, minimum: self.theme.spacing.xs)
    case .standard, .expanded:
      // Standard spacing for larger watches
      self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s)
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
    onShare: @escaping () -> Void)
  {
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
      VStack(alignment: .leading, spacing: self.theme.spacing.s) {
        self.controlsHeader

        let gridSpacing = self.layout.dimension(self.theme.spacing.xs, minimum: self.theme.spacing.xs * 0.75)
        LazyVGrid(columns: self.controlColumns, spacing: gridSpacing) {
          WorkoutControlTile(
            title: self.isPaused ? "Resume" : "Pause",
            systemImage: self.isPaused ? "play.fill" : "pause.fill",
            tint: self.theme.colors.matchWarning,
            foreground: self.theme.colors.backgroundPrimary,
            isDisabled: self.isEnding,
            style: self.tileStyle,
            action: {
              if self.isPaused {
                self.timerModel.resumeMatch()
              } else {
                self.timerModel.pauseMatch()
              }
            })

          WorkoutControlTile(
            title: "Segment",
            systemImage: "flag.checkered",
            tint: self.theme.colors.matchPositive,
            foreground: self.theme.colors.backgroundPrimary,
            badgeText: self.lapCount > 0 ? "\(self.lapCount)" : nil,
            isDisabled: self.isEnding || self.isRecordingSegment,
            isLoading: self.isRecordingSegment,
            style: self.tileStyle,
            action: self.onMarkSegment)

          WorkoutControlTile(
            title: "End",
            systemImage: "xmark",
            tint: self.theme.colors.matchCritical,
            foreground: self.theme.colors.backgroundPrimary,
            isDisabled: self.isEnding,
            style: self.tileStyle,
            action: self.onEnd)

          WorkoutControlTile(
            title: "New",
            systemImage: "plus",
            tint: self.theme.colors.accentSecondary,
            foreground: self.theme.colors.backgroundPrimary,
            isDisabled: self.isEnding,
            style: self.tileStyle,
            action: self.onRequestNewSession)

          WorkoutControlTile(
            title: "Share",
            systemImage: "square.and.arrow.up",
            tint: self.theme.colors.accentPrimary,
            foreground: self.theme.colors.backgroundPrimary,
            isDisabled: self.isEnding,
            style: self.tileStyle,
            action: self.onShare)

          WorkoutControlTilePlaceholder(style: self.tileStyle)
        }
      }
      .padding(.horizontal, self.theme.spacing.s)
      .padding(.top, self.theme.spacing.m)
      .padding(.bottom, self.layout.safeAreaBottomPadding)
    }
    .scrollIndicators(.visible)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private var controlColumns: [GridItem] {
    let spacing = self.layout.dimension(self.theme.spacing.xs, minimum: self.theme.spacing.xs * 0.75)
    return [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
  }

  private var controlsHeader: some View {
    Text(self.session.title)
      .font(self.theme.typography.cardHeadline)
      .foregroundStyle(self.theme.colors.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
  }

  private var tileStyle: WorkoutControlTile.Style {
    let circle = self.layout.dimension(44, minimum: 38)
    let icon = self.layout.dimension(19, minimum: 16, maximum: 24)
    let verticalSpacing = self.theme.spacing.xs
    var style = WorkoutControlTile.Style()
    style.circleDiameter = circle
    style.iconSize = icon
    style.titleFont = self.theme.typography.caption.weight(.medium)
    style.titleColor = self.theme.colors.textPrimary
    style.verticalSpacing = verticalSpacing
    style.tileVerticalPadding = verticalSpacing * 0.4
    style.badgeFont = self.theme.typography.caption.weight(.semibold)
    style.badgeHorizontalPadding = 4
    style.badgeVerticalPadding = 3
    let spacing = style.verticalSpacing ?? verticalSpacing
    let padding = style.tileVerticalPadding ?? verticalSpacing * 0.4
    style.preferredHeight = style.circleDiameter + spacing + self.layout.dimension(22, minimum: 18) + padding * 2
    return style
  }
}

private struct WorkoutSessionRatingPlaceholderPage: View {
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    VStack(spacing: self.theme.spacing.m) {
      self.featureGlyph
        .frame(maxWidth: .infinity, alignment: .center)

      Text("Difficulty Rating Coming Soon")
        .font(self.theme.typography.cardHeadline)
        .fontWeight(.semibold)
        .foregroundStyle(self.theme.colors.textPrimary)
        .multilineTextAlignment(.center)

      Spacer()
    }
    .padding(.horizontal, self.theme.spacing.m)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
  }

  private var featureGlyph: some View {
    let diameter = self.layout.dimension(72, minimum: 60, maximum: 88)
    return ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: [
              self.theme.colors.accentSecondary.opacity(0.45),
              self.theme.colors.accentSecondary.opacity(0.2),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing))
        .frame(width: diameter, height: diameter)

      Image(systemName: "star.fill")
        .font(.system(size: diameter * 0.45, weight: .bold))
        .foregroundStyle(self.theme.colors.accentSecondary)
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
      size: self.layout.dimension(36, minimum: 30, maximum: 42),
      weight: .semibold,
      design: .rounded).monospacedDigit()
  }

  // Smaller label font matching Apple's secondary text
  private var labelFont: Font {
    .system(size: self.layout.dimension(13, minimum: 11, maximum: 15), weight: .regular)
  }

  var body: some View {
    switch self.metric.type {
    case .heartRate:
      self.heartRateView
    case .activeEnergy:
      self.activeEnergyView
    case .distance:
      self.distanceView
    }
  }

  private var heartRateView: some View {
    HStack(alignment: .lastTextBaseline, spacing: self.theme.spacing.xs) {
      Text(self.metric.value)
        .font(self.valueFont)
        .foregroundStyle(self.theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .layoutPriority(1)

      Image(systemName: "heart.fill")
        .font(.system(size: self.layout.dimension(16, minimum: 14, maximum: 18), weight: .semibold))
        .foregroundStyle(.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var activeEnergyView: some View {
    HStack(alignment: .lastTextBaseline, spacing: self.theme.spacing.xs) {
      // Number displayed prominently (matching Apple's design)
      Text(self.metric.value)
        .font(self.valueFont)
        .foregroundStyle(self.theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .layoutPriority(1)

      // Label text after the number (Apple shows "1 ACTIVE KJ" format)
      if let unit = metric.unit {
        Text("ACTIVE \(unit.uppercased())")
          .font(self.labelFont)
          .tracking(0.3)
          .foregroundStyle(self.theme.colors.textSecondary.opacity(0.85))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var distanceView: some View {
    HStack(alignment: .lastTextBaseline, spacing: 0) {
      Text(self.metric.value)
        .font(self.valueFont)
        .foregroundStyle(self.theme.colors.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .layoutPriority(1)

      if let unit = metric.unit {
        Text(unit.uppercased())
          .font(self.labelFont)
          .tracking(0.3)
          .foregroundStyle(self.theme.colors.textSecondary.opacity(0.85))
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
      size: self.layout.dimension(46, minimum: 42, maximum: 54),
      weight: .bold,
      design: .rounded).monospacedDigit()
  }

  var body: some View {
    // Center the timer text (matching Apple's design)
    HStack {
      Spacer()
      Text(self.timerModel.matchTime)
        .font(self.timerFont)
        .tracking(-0.2)
        .foregroundStyle(self.timerModel.isPaused ? self.theme.colors.textSecondary : self.timerYellow)
      Spacer()
    }
    .contentShape(Rectangle())
    .onTapGesture {
      self.haptics.play(.tap)
      if self.timerModel.isPaused {
        self.timerModel.resumeMatch()
      } else {
        self.timerModel.pauseMatch()
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
      .fill(self.greenBackground)
      .frame(width: self.glyphDiameter, height: self.glyphDiameter)
      .overlay(
        Image(systemName: self.iconName)
          .font(.system(size: self.iconSize, weight: .semibold))
          .foregroundStyle(.white))
  }

  private var glyphDiameter: CGFloat {
    self.layout.dimension(44, minimum: 40, maximum: 48)
  }

  private var iconSize: CGFloat {
    self.layout.dimension(20, minimum: 18, maximum: 22)
  }

  private var iconName: String {
    switch self.kind {
    case .outdoorRun, .indoorRun:
      "figure.run"
    case .outdoorWalk:
      "figure.walk"
    case .indoorCycle:
      "bicycle"
    case .strength:
      "dumbbell"
    case .mobility:
      "figure.cooldown"
    case .refereeDrill:
      "whistle"
    case .custom:
      "star"
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
    onRequestNewSession: {})
    .theme(DefaultTheme())
    .watchLayoutScale(WatchLayoutScale(category: .compact))
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
    onRequestNewSession: {})
    .theme(DefaultTheme())
    .watchLayoutScale(WatchLayoutScale(category: .standard))
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
    onRequestNewSession: {})
    .theme(DefaultTheme())
    .watchLayoutScale(WatchLayoutScale(category: .expanded))
}

private enum WorkoutSessionPreviewData {
  static let segments: [WorkoutSegment] = [
    WorkoutSegment(name: "Warm-up", purpose: .warmup, plannedDuration: 300, plannedDistance: 0.4),
    WorkoutSegment(
      name: "Tempo",
      purpose: .work,
      plannedDuration: 900,
      plannedDistance: 2.4,
      target: .init(intensityZone: .tempo)),
    WorkoutSegment(name: "Cooldown", purpose: .cooldown, plannedDuration: 300, plannedDistance: 0.6),
  ]

  static let active: WorkoutSession = .init(
    state: .active,
    kind: .outdoorRun,
    title: "Outdoor Run",
    startedAt: Date().addingTimeInterval(-1200),
    segments: segments,
    summary: .init(
      averageHeartRate: 134,
      maximumHeartRate: 168,
      totalDistance: 4200,
      activeEnergy: 310,
      duration: 1200),
    presetId: UUID())

  static let liveMetrics = WorkoutLiveMetrics(
    sessionId: active.id,
    elapsedTime: 1260,
    totalDistance: 4580,
    activeEnergy: 328,
    heartRate: 138)
}
