import SwiftUI
import RefWatchCore
import RefWorkoutCore

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
          ForEach(Array(items.enumerated()), id: \.element.id) { enumerated in
            let index = enumerated.offset
            let item = enumerated.element
            WorkoutSelectionTileView(
              item: item,
              isFocused: scrollPosition == item.id,
              dwellState: dwellState,
              dwellConfiguration: dwellConfiguration,
              isBusy: isBusy,
              onSelect: { onSelect(item) },
              onRequestAccess: onRequestAccess,
              onReloadPresets: onReloadPresets
            )
            .id(item.id)
            .containerRelativeFrame(.vertical)
            .zIndex(zIndexValue(for: index, isFocused: scrollPosition == item.id))
          }
        }
        .padding(.vertical, geometry.size.height * 0.12)
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: ScrollOffsetPreferenceKey.self,
              value: proxy.frame(in: .named("workoutCarousel")).minY
            )
          }
        )
      }
      .scrollTargetLayout()
      .scrollIndicators(.hidden)
      .scrollPosition(id: $scrollPosition)
      .coordinateSpace(name: "workoutCarousel")
      .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
        updateVelocity(with: offset)
      }
    }
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    .onChange(of: items) { _ in
      synchroniseInitialScrollPosition()
    }
    .onChange(of: focusedSelectionID) { newValue in
      guard let newValue, newValue != scrollPosition else { return }
      scrollPosition = newValue
    }
    .onChange(of: scrollPosition) { newValue in
      onFocusChange(newValue, lastReportedVelocity)
    }
    .onChange(of: dwellState) { newValue in
      if case .locked = newValue {
        haptics.play(.success)
      }
    }
    .task {
      synchroniseInitialScrollPosition()
    }
  }

  private func updateVelocity(with offset: CGFloat) {
    let now = Date()
    if lastOffsetTimestamp == .distantPast {
      lastOffset = offset
      lastOffsetTimestamp = now
      return
    }

    let delta = offset - lastOffset
    let interval = now.timeIntervalSince(lastOffsetTimestamp)
    guard interval > 0 else { return }

    let pointsPerSecond = abs(delta / interval)
    let normalizedVelocity = min(pointsPerSecond / 900, 2)

    lastOffset = offset
    lastOffsetTimestamp = now
    lastReportedVelocity = normalizedVelocity
    onFocusChange(scrollPosition, normalizedVelocity)
  }

  private func synchroniseInitialScrollPosition() {
    guard !hasInitializedScrollPosition else { return }
    guard let target = focusedSelectionID ?? items.first?.id else { return }
    hasInitializedScrollPosition = true
    scrollPosition = target
    DispatchQueue.main.async {
      onFocusChange(target, 0)
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
      if item.interaction == .preview {
        Button(action: onSelect) {
          tileContent
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
      } else {
        tileContent
      }
    }
  }

  @ViewBuilder
  private var tileContent: some View {
    if case .authorization(let status, let diagnostics) = item.content {
      tileContainer(contentSpacing: theme.spacing.m, verticalPadding: theme.spacing.m) {
        authorizationContent(status: status, diagnostics: diagnostics)
      }
    } else {
      tileContainer {
        standardTileContent
      }
    }
  }

  @ViewBuilder
  private var dwellIndicator: some View {
    if case .pending(let id, let start) = dwellState, id == item.id {
      DwellProgressIndicator(startedAt: start, configuration: dwellConfiguration)
    } else if case .locked(let id, _) = dwellState, id == item.id {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(theme.colors.accentSecondary)
        .padding(theme.spacing.xs)
    }
  }

  @ViewBuilder
  private var iconView: some View {
    if let icon = item.iconSystemName {
      Image(systemName: icon)
        .font(.system(size: 32, weight: .medium))
        .foregroundStyle(theme.colors.accentSecondary)
        .opacity(isBusy && item.interaction == .preview ? 0.4 : 1)
    } else {
      Spacer(minLength: 0)
    }
  }

  private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(theme.typography.button)
        .foregroundStyle(theme.colors.textInverted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.s)
        .background(
          RoundedRectangle(cornerRadius: theme.components.controlCornerRadius, style: .continuous)
            .fill(theme.colors.accentSecondary)
        )
    }
    .buttonStyle(.plain)
    .disabled(isBusy)
  }

  private func tileContainer<Content: View>(contentSpacing: CGFloat? = nil, verticalPadding: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: contentSpacing ?? theme.spacing.m) {
      content()
    }
    .padding(.vertical, verticalPadding ?? theme.spacing.l)
    .padding(.horizontal, theme.spacing.s)
    .frame(maxWidth: .infinity)
    .background(theme.colors.backgroundPrimary)
    .overlay(alignment: .topTrailing) {
      dwellIndicator
    }
    .overlay(alignment: .bottom) {
      if case .locked(let id, _) = dwellState, id == item.id {
        Rectangle()
          .fill(theme.colors.accentSecondary)
          .frame(height: 2)
      } else {
        Rectangle()
          .fill(theme.colors.outlineMuted.opacity(0.3))
          .frame(height: 1)
      }
    }
    .scaleEffect(isFocused ? 1.02 : 0.94)
    .opacity(isFocused ? 1.0 : 0.6)
    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isFocused)
    .opacity(isBusy && item.interaction == .preview ? 0.5 : 1)
  }

  private var standardTileContent: some View {
    VStack(spacing: theme.spacing.m) {
      iconView
        .frame(height: 42)

      VStack(spacing: theme.spacing.xs) {
        Text(item.title)
          .font(theme.typography.cardHeadline)
          .foregroundStyle(theme.colors.textPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(2)

        if let subtitle = item.subtitle {
          Text(subtitle)
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
        }
      }

      if let diagnostics = item.diagnosticsDescription {
        Text(diagnostics)
          .font(theme.typography.caption)
          .foregroundStyle(theme.colors.accentSecondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  private func authorizationContent(status: WorkoutAuthorizationStatus, diagnostics: [WorkoutAuthorizationMetric]) -> some View {
    VStack(spacing: theme.spacing.m) {
      Image(systemName: item.iconSystemName ?? "heart.text.square")
        .font(.system(size: 28, weight: .medium))
        .foregroundStyle(theme.colors.accentSecondary)
        .accessibilityHidden(true)

      VStack(spacing: theme.spacing.xs) {
        Text(item.title)
          .font(theme.typography.cardHeadline)
          .foregroundStyle(theme.colors.textPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .minimumScaleFactor(0.85)

        if let subtitle = item.subtitle {
          Text(subtitle)
            .font(theme.typography.cardMeta)
            .foregroundStyle(theme.colors.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
        }
      }

      if let summary = WorkoutSelectionItem.authorizationDiagnosticsSummary(for: diagnostics) {
        Label(summary, systemImage: "info.circle")
          .font(theme.typography.caption)
          .foregroundStyle(theme.colors.accentSecondary)
          .labelStyle(.titleAndIcon)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .frame(maxWidth: .infinity)
      }

      primaryButton(title: authorizationButtonTitle, action: onRequestAccess)
    }
  }

  private var authorizationButtonTitle: String {
    switch item.authorizationStatus?.state {
    case .notDetermined:
      return "Grant Access"
    case .denied:
      return "Review Access"
    case .limited:
      return "Review Access"
    default:
      return "Manage Access"
    }
  }
}

private struct DwellProgressIndicator: View {
  let startedAt: Date
  let configuration: WorkoutSelectionDwellConfiguration

  var body: some View {
    TimelineView(.animation) { timeline in
      let duration = max(configuration.dwellDuration, 0.1)
      let progress = min(max(timeline.date.timeIntervalSince(startedAt) / duration, 0), 1)

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
    onReloadPresets: {}
  )
  .theme(DefaultTheme())
  .hapticsProvider(NoopHaptics())
}

private enum WorkoutHomePreviewData {
  static let items: [WorkoutSelectionItem] = {
    let status = WorkoutAuthorizationStatus(state: .limited, deniedMetrics: [.vo2Max])
    let authorization = WorkoutSelectionItem(id: .authorization, content: .authorization(status: status, diagnostics: [.vo2Max]))
    let session = WorkoutSession(
      state: .ended,
      kind: .outdoorRun,
      title: "Intervals",
      startedAt: Date().addingTimeInterval(-2_700),
      endedAt: Date().addingTimeInterval(-1_200)
    )
    let last = WorkoutSelectionItem(id: .lastCompleted(session.id), content: .lastCompleted(session: session))
    let quick = WorkoutSelectionItem(id: .quickStart(.outdoorRun), content: .quickStart(kind: .outdoorRun))
    let preset = WorkoutSelectionItem(id: .preset(UUID()), content: .preset(preset: WorkoutModeBootstrap.samplePreset))
    let empty = WorkoutSelectionItem(id: .emptyPresets, content: .emptyPresets)
    return [authorization, last, quick, preset, empty]
  }()
}
