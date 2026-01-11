import RefWatchCore
import RefWorkoutCore
import SwiftUI

struct WorkoutHomeView: View {
  let items: [WorkoutSelectionItem]
  let focusedSelectionID: WorkoutSelectionItem.ID?
  let dwellState: WorkoutSelectionDwellState
  let dwellConfiguration: WorkoutSelectionDwellConfiguration
  let isBusy: Bool
  let onFocusChange: (WorkoutSelectionItem.ID?, Double) -> Void
  let onSelect: (WorkoutSelectionItem) -> Void
  let onRequestAccess: () -> Void
  let onReloadPresets: () -> Void

  @Environment(\.theme) private var theme
  @Environment(\.haptics) private var haptics

  @State private var scrollPosition: WorkoutSelectionItem.ID?
  @State private var hasInitializedScrollPosition = false
  @State private var lastOffset: CGFloat = 0
  @State private var lastOffsetTimestamp: Date = .distantPast
  @State private var lastReportedVelocity: Double = 0

  var body: some View {
    GeometryReader { geometry in
      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 0) {
          ForEach(Array(self.items.enumerated()), id: \.element.id) { enumerated in
            let index = enumerated.offset
            let item = enumerated.element
            WorkoutSelectionTileView(
              item: item,
              isFocused: self.scrollPosition == item.id,
              dwellState: self.dwellState,
              dwellConfiguration: self.dwellConfiguration,
              isBusy: self.isBusy,
              onSelect: { self.onSelect(item) },
              onRequestAccess: self.onRequestAccess,
              onReloadPresets: self.onReloadPresets)
              .id(item.id)
              .containerRelativeFrame(.vertical)
              .zIndex(self.zIndexValue(for: index, isFocused: self.scrollPosition == item.id))
          }
        }
        .padding(.vertical, geometry.size.height * 0.12)
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: ScrollOffsetPreferenceKey.self,
              value: proxy.frame(in: .named("workoutCarousel")).minY)
          })
      }
      .scrollTargetLayout()
      .scrollIndicators(.hidden)
      .scrollPosition(id: self.$scrollPosition)
      .coordinateSpace(name: "workoutCarousel")
      .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
        self.updateVelocity(with: offset)
      }
    }
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .onChange(of: self.items) { _, _ in
      self.synchroniseInitialScrollPosition()
    }
    .onChange(of: self.focusedSelectionID) { _, newValue in
      guard let newValue, newValue != scrollPosition else { return }
      self.scrollPosition = newValue
    }
    .onChange(of: self.scrollPosition) { _, newValue in
      self.onFocusChange(newValue, self.lastReportedVelocity)
    }
    .onChange(of: self.dwellState) { _, newValue in
      if case .locked = newValue {
        self.haptics.play(.success)
      }
    }
    .task {
      self.synchroniseInitialScrollPosition()
    }
  }

  private func updateVelocity(with offset: CGFloat) {
    let now = Date()
    if self.lastOffsetTimestamp == .distantPast {
      self.lastOffset = offset
      self.lastOffsetTimestamp = now
      return
    }

    let delta = offset - self.lastOffset
    let interval = now.timeIntervalSince(self.lastOffsetTimestamp)
    guard interval > 0 else { return }

    let pointsPerSecond = abs(delta / interval)
    let normalizedVelocity = min(pointsPerSecond / 900, 2)

    self.lastOffset = offset
    self.lastOffsetTimestamp = now
    self.lastReportedVelocity = normalizedVelocity
    self.onFocusChange(self.scrollPosition, normalizedVelocity)
  }

  private func synchroniseInitialScrollPosition() {
    guard !self.hasInitializedScrollPosition else { return }
    guard let target = focusedSelectionID ?? items.first?.id else { return }
    self.hasInitializedScrollPosition = true
    self.scrollPosition = target
    DispatchQueue.main.async {
      self.onFocusChange(target, 0)
    }
  }

  private func zIndexValue(for index: Int, isFocused: Bool) -> Double {
    let base = Double(items.count - index)
    return isFocused ? base + 0.5 : base
  }
}

private struct WorkoutSelectionTileView: View {
  let item: WorkoutSelectionItem
  let isFocused: Bool
  let dwellState: WorkoutSelectionDwellState
  let dwellConfiguration: WorkoutSelectionDwellConfiguration
  let isBusy: Bool
  let onSelect: () -> Void
  let onRequestAccess: () -> Void
  let onReloadPresets: () -> Void

  @Environment(\.theme) private var theme

  var body: some View {
    Group {
      if self.item.interaction == .preview {
        Button(action: self.onSelect) {
          self.tileContent
        }
        .buttonStyle(.plain)
        .disabled(self.isBusy)
      } else {
        self.tileContent
      }
    }
  }

  @ViewBuilder
  private var tileContent: some View {
    if case let .authorization(status, diagnostics) = item.content {
      self.tileContainer(contentSpacing: self.theme.spacing.m, verticalPadding: self.theme.spacing.m) {
        self.authorizationContent(status: status, diagnostics: diagnostics)
      }
    } else {
      self.tileContainer {
        self.standardTileContent
      }
    }
  }

  @ViewBuilder
  private var dwellIndicator: some View {
    if case let .pending(id, start) = dwellState, id == item.id {
      DwellProgressIndicator(startedAt: start, configuration: self.dwellConfiguration)
    } else if case let .locked(id, _) = dwellState, id == item.id {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(self.theme.colors.accentSecondary)
        .padding(self.theme.spacing.xs)
    }
  }

  @ViewBuilder
  private var iconView: some View {
    if let icon = item.iconSystemName {
      Image(systemName: icon)
        .font(.system(size: 32, weight: .medium))
        .foregroundStyle(self.theme.colors.accentSecondary)
        .opacity(self.isBusy && self.item.interaction == .preview ? 0.4 : 1)
    } else {
      Spacer(minLength: 0)
    }
  }

  private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(self.theme.typography.button)
        .foregroundStyle(self.theme.colors.textInverted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, self.theme.spacing.s)
        .background(
          RoundedRectangle(cornerRadius: self.theme.components.controlCornerRadius, style: .continuous)
            .fill(self.theme.colors.accentSecondary))
    }
    .buttonStyle(.plain)
    .disabled(self.isBusy)
  }

  private func tileContainer(
    contentSpacing: CGFloat? = nil,
    verticalPadding: CGFloat? = nil,
    @ViewBuilder content: () -> some View) -> some View
  {
    VStack(spacing: contentSpacing ?? self.theme.spacing.m) {
      content()
    }
    .padding(.vertical, verticalPadding ?? self.theme.spacing.l)
    .padding(.horizontal, self.theme.spacing.s)
    .frame(maxWidth: .infinity)
    .background(self.theme.colors.backgroundPrimary)
    .overlay(alignment: .topTrailing) {
      self.dwellIndicator
    }
    .overlay(alignment: .bottom) {
      if case let .locked(id, _) = dwellState, id == item.id {
        Rectangle()
          .fill(self.theme.colors.accentSecondary)
          .frame(height: 2)
      } else {
        Rectangle()
          .fill(self.theme.colors.outlineMuted.opacity(0.3))
          .frame(height: 1)
      }
    }
    .scaleEffect(self.isFocused ? 1.02 : 0.94)
    .opacity(self.isFocused ? 1.0 : 0.6)
    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: self.isFocused)
    .opacity(self.isBusy && self.item.interaction == .preview ? 0.5 : 1)
  }

  private var standardTileContent: some View {
    VStack(spacing: self.theme.spacing.m) {
      self.iconView
        .frame(height: 42)

      VStack(spacing: self.theme.spacing.xs) {
        Text(self.item.title)
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(2)

        if let subtitle = item.subtitle {
          Text(subtitle)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
        }
      }

      if let diagnostics = item.diagnosticsDescription {
        Text(diagnostics)
          .font(self.theme.typography.caption)
          .foregroundStyle(self.theme.colors.accentSecondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  private func authorizationContent(
    status: WorkoutAuthorizationStatus,
    diagnostics: [WorkoutAuthorizationMetric]) -> some View
  {
    VStack(spacing: self.theme.spacing.m) {
      Image(systemName: self.item.iconSystemName ?? "heart.text.square")
        .font(.system(size: 28, weight: .medium))
        .foregroundStyle(self.theme.colors.accentSecondary)
        .accessibilityHidden(true)

      VStack(spacing: self.theme.spacing.xs) {
        Text(self.item.title)
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .minimumScaleFactor(0.85)

        if let subtitle = item.subtitle {
          Text(subtitle)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
        }
      }

      if let summary = WorkoutSelectionItem.authorizationDiagnosticsSummary(for: diagnostics) {
        Label(summary, systemImage: "info.circle")
          .font(self.theme.typography.caption)
          .foregroundStyle(self.theme.colors.accentSecondary)
          .labelStyle(.titleAndIcon)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .frame(maxWidth: .infinity)
      }

      self.primaryButton(title: self.authorizationButtonTitle, action: self.onRequestAccess)
    }
  }

  private var authorizationButtonTitle: String {
    switch self.item.authorizationStatus?.state {
    case .notDetermined:
      "Grant on iPhone"
    case .denied:
      "Fix on iPhone"
    case .limited:
      "Update on iPhone"
    default:
      "Manage on iPhone"
    }
  }
}

private struct DwellProgressIndicator: View {
  let startedAt: Date
  let configuration: WorkoutSelectionDwellConfiguration

  var body: some View {
    TimelineView(.animation) { timeline in
      let duration = max(configuration.dwellDuration, 0.1)
      let progress = min(max(timeline.date.timeIntervalSince(self.startedAt) / duration, 0), 1)

      ProgressView(value: progress)
        .progressViewStyle(.circular)
        .scaleEffect(0.6)
    }
    .padding(4)
  }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

#Preview("Workout Carousel") {
  WorkoutHomeView(
    items: WorkoutHomePreviewData.items,
    focusedSelectionID: WorkoutHomePreviewData.items.first?.id,
    dwellState: .idle,
    dwellConfiguration: .standard,
    isBusy: false,
    onFocusChange: { _, _ in },
    onSelect: { _ in },
    onRequestAccess: {},
    onReloadPresets: {})
    .theme(DefaultTheme())
    .hapticsProvider(NoopHaptics())
}

private enum WorkoutHomePreviewData {
  static let items: [WorkoutSelectionItem] = {
    let status = WorkoutAuthorizationStatus(state: .limited, deniedMetrics: [.vo2Max])
    let authorization = WorkoutSelectionItem(
      id: .authorization,
      content: .authorization(status: status, diagnostics: [.vo2Max]))
    let session = WorkoutSession(
      state: .ended,
      kind: .outdoorRun,
      title: "Intervals",
      startedAt: Date().addingTimeInterval(-2700),
      endedAt: Date().addingTimeInterval(-1200))
    let last = WorkoutSelectionItem(id: .lastCompleted(session.id), content: .lastCompleted(session: session))
    let quick = WorkoutSelectionItem(id: .quickStart(.outdoorRun), content: .quickStart(kind: .outdoorRun))
    let preset = WorkoutSelectionItem(id: .preset(UUID()), content: .preset(preset: WorkoutModeBootstrap.samplePreset))
    let empty = WorkoutSelectionItem(id: .emptyPresets, content: .emptyPresets)
    return [authorization, last, quick, preset, empty]
  }()
}
