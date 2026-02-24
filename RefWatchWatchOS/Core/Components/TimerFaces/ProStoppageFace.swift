// ProStoppageFace.swift
// Advanced timer face emphasizing per-period context and stoppage

import SwiftUI
import RefWatchCore

public struct ProStoppageFace: View {
    @Environment(\.haptics) private var haptics
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    let model: TimerFaceModel

    public init(model: TimerFaceModel) { self.model = model }

    public var body: some View {
        GeometryReader { proxy in
            let scale = FaceSizer.scale(forHeight: proxy.size.height)
            let width = proxy.size.width
            Group {
                if model.isHalfTime { halfTimeView(scale: scale) } else { runningMatchView(scale: scale, width: width) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("proStoppageFace")
    }

    // MARK: - Constants
    private enum Constants {
        // Baseline sizes (scaled dynamically by available height)
        static let prominentFontBase: CGFloat = 34
        static let iconSize: CGFloat = 44
        static let verticalSpacingBase: CGFloat = 4
        static let rowValueFontBase: CGFloat = 17
        static let stoppageFontBase: CGFloat = 15
        static let halfTimeLargeFontBase: CGFloat = 44
        static let halfTimeVerticalPaddingBase: CGFloat = 28
        static let contentVerticalPaddingBase: CGFloat = 4
        static let bottomInsetBase: CGFloat = 8
    }

    // MARK: - Subviews
    @ViewBuilder
    private func halfTimeView(scale: CGFloat) -> some View {
        Group {
            if model.waitingForHalfTimeStart {
                Spacer()
                IconButton(
                    icon: "checkmark.circle.fill",
                    color: theme.colors.matchPositive,
                    size: max(32, Constants.iconSize * scale),
                    action: {
                        haptics.play(.resume)
                        model.startHalfTimeManually()
                    }
                )
                .padding(.bottom, theme.spacing.m * scale)
                Spacer()
            } else {
                Text(model.halfTimeElapsed)
                    .font(theme.typography.timerPrimary)
                    .foregroundStyle(theme.colors.textPrimary)
                    .padding(.vertical, Constants.halfTimeVerticalPaddingBase * scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .scaleEffect(scale, anchor: .center)
            }
        }
    }

    @ViewBuilder
    private func runningMatchView(scale: CGFloat, width: CGFloat) -> some View {
        let rowMaxWidth = min(width * 0.78, 180)
        VStack(spacing: Constants.verticalSpacingBase * scale) {
            VStack(spacing: Constants.verticalSpacingBase * scale) {
                // Prominent per-period context: time remaining in current period
                Text(model.periodTimeRemaining)
                    .font(theme.typography.timerPrimary)
                    .foregroundStyle(theme.colors.accentSecondary)
                    .scaleEffect(max(1.0, scale * 1.04), anchor: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(model.periodTimeRemaining)

                // Elapsed row (total match time)
                HStack {
                    Text("Elapsed")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                    Text(model.matchTime)
                        .font(theme.typography.timerSecondary)
                        .foregroundStyle(theme.colors.textPrimary)
                        .scaleEffect(scale * 0.9, anchor: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: rowMaxWidth)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Match time")
                .accessibilityValue(model.matchTime)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                haptics.play(.tap)
                if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
            }

            // Stoppage row (dedicated tap target to toggle stoppage while running)
            HStack {
                Text("Stoppage")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                Spacer()
                Text("+\(model.formattedStoppageTime)")
                    .font(theme.typography.timerTertiary)
                    .foregroundStyle(model.isInStoppage ? theme.colors.matchWarning : theme.colors.textSecondary)
                    .scaleEffect(scale * 0.85, anchor: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: rowMaxWidth)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                haptics.play(.tap)
                // Only allow manual stoppage toggling while the period is running.
                guard model.isPaused == false else { return }
                if model.isInStoppage { model.endStoppage() } else { model.beginStoppage() }
            }
        }
        .padding(.vertical, Constants.contentVerticalPaddingBase * scale)
        .padding(.bottom, max(Constants.bottomInsetBase * scale, layout.timerBottomPadding * 0.6))
    }
}

#Preview {
    // Use NoopHaptics for previews to avoid platform haptic dependencies
    ProStoppageFace(model: MatchViewModel(haptics: NoopHaptics()))
        .hapticsProvider(NoopHaptics())
}
