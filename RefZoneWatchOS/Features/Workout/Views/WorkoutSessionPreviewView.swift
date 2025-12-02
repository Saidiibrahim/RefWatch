import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutSessionPreviewView: View {
  let item: WorkoutSelectionItem
  let isStarting: Bool
  let error: WorkoutError?
  let onStart: () -> Void
  let onRetry: () -> Void
  let onReturnToList: () -> Void

  @Environment(\.theme) private var theme
  @Environment(\.haptics) private var haptics

  var body: some View {
    GeometryReader { proxy in
      render(in: proxy)
    }
    .workoutCrownReturnGesture(onReturn: onReturnToList)
    .onAppear {
      if error != nil {
        haptics.play(.failure)
      }
    }
    .onChange(of: error) { _, newValue in
      if newValue != nil {
        haptics.play(.failure)
      }
    }
  }

  private func render(in proxy: GeometryProxy) -> some View {
    let metrics = LayoutMetrics(
      size: proxy.size,
      safeAreaInsets: proxy.safeAreaInsets,
      spacing: theme.spacing
    )

    return ZStack {
      // Background
      theme.colors.backgroundPrimary
        .ignoresSafeArea()

      // Central content - icon cluster and title
      centralContent(metrics: metrics)
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

      // Error banner at bottom
      if let error {
        errorBanner(error)
          .padding(.horizontal, metrics.errorHorizontalPadding)
          .padding(.bottom, metrics.errorBottomPadding)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      }
    }
    .frame(width: proxy.size.width, height: proxy.size.height)
  }

  private func centralContent(metrics: LayoutMetrics) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: metrics.topSpacerMinLength)

      VStack(spacing: metrics.iconTitleSpacing) {
        workoutIcon(metrics: metrics)

        Text(item.title)
          .font(theme.typography.heroSubtitle)
          .foregroundStyle(theme.colors.textPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .center)

      primaryControl(metrics: metrics)
        .padding(.top, metrics.titleButtonSpacing)

      Spacer(minLength: metrics.bottomSpacerMinLength)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(.horizontal, metrics.contentHorizontalPadding)
  }

  @ViewBuilder
  private func workoutIcon(metrics: LayoutMetrics) -> some View {
    if let icon = item.iconSystemName {
      Image(systemName: icon)
        .font(.system(size: metrics.iconSize, weight: .medium))
        .foregroundStyle(theme.colors.accentSecondary)
        .frame(width: metrics.iconSize, height: metrics.iconSize)
        .accessibilityHidden(true)
    }
  }

  private func errorBanner(_ error: WorkoutError) -> some View {
    VStack(spacing: theme.spacing.xs) {
      if let description = error.errorDescription {
        Text(description)
          .font(theme.typography.caption)
          .foregroundStyle(theme.colors.matchWarning)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.s)
    .background(
      Capsule()
        .fill(theme.colors.backgroundSecondary)
        .overlay(
          Capsule()
            .stroke(theme.colors.matchWarning.opacity(0.4), lineWidth: 1)
        )
    )
  }

  @ViewBuilder
  private func primaryControl(metrics: LayoutMetrics) -> some View {
    if isStarting {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(theme.colors.accentSecondary)
        .frame(width: metrics.primaryDiameter, height: metrics.primaryDiameter)
        .background(
          Circle()
            .fill(theme.colors.backgroundSecondary.opacity(0.6))
        )
    } else {
      Button(action: primaryAction) {
        Image(systemName: error != nil ? "arrow.clockwise" : "play.fill")
          .font(.system(size: metrics.primaryDiameter * 0.42, weight: .semibold))
          .foregroundStyle(theme.colors.backgroundPrimary)
          .frame(width: metrics.primaryDiameter, height: metrics.primaryDiameter)
          .background(
            Circle()
              .fill(theme.colors.accentSecondary)
          )
      }
      .buttonStyle(.plain)
    }
  }

  private func primaryAction() {
    if error != nil {
      onRetry()
    } else {
      onStart()
    }
  }
}

private struct LayoutMetrics {
  let size: CGSize
  let safeAreaInsets: EdgeInsets
  let spacing: SpacingScale

  init(size: CGSize, safeAreaInsets: EdgeInsets, spacing: SpacingScale) {
    self.size = size
    self.safeAreaInsets = safeAreaInsets
    self.spacing = spacing
  }

  private func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.max(minValue, Swift.min(value, maxValue))
  }

  private var minDimension: CGFloat { Swift.min(size.width, size.height) }

  var primaryDiameter: CGFloat {
    clamped(minDimension * 0.35, min: 50, max: 86)
  }

  var iconSize: CGFloat {
    primaryDiameter * 0.72
  }

  var contentHorizontalPadding: CGFloat {
    Swift.max(spacing.m, size.width * 0.07)
  }

  var iconTitleSpacing: CGFloat {
    Swift.max(spacing.s, iconSize * 0.08)
  }

  var titleButtonSpacing: CGFloat {
    Swift.max(spacing.l, primaryDiameter * 0.22)
  }

  var topSpacerMinLength: CGFloat {
    Swift.max(0, Swift.max(spacing.l, size.height * 0.12) - safeAreaInsets.top)
  }

  var bottomSpacerMinLength: CGFloat {
    Swift.max(0, Swift.max(spacing.xl, size.height * 0.22) - safeAreaInsets.bottom)
  }

  var errorBottomPadding: CGFloat {
    spacing.xl * 1.6
  }

  var errorHorizontalPadding: CGFloat {
    Swift.max(spacing.m, size.width * 0.08)
  }
}

#Preview("Quick Start Preview") {
  WorkoutSessionPreviewView(
    item: WorkoutSelectionItem(id: .quickStart(.outdoorRun), content: .quickStart(kind: .outdoorRun)),
    isStarting: false,
    error: nil,
    onStart: {},
    onRetry: {},
    onReturnToList: {}
  )
  .theme(DefaultTheme())
  .hapticsProvider(NoopHaptics())
}
