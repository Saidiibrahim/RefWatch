// GlanceTimerFace.swift
// Glanceable timer face emphasizing large elapsed time and remaining time

import SwiftUI
import RefWatchCore

public struct GlanceTimerFace: View {
    @Environment(\.haptics) private var haptics
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    let model: TimerFaceModel

    public init(model: TimerFaceModel) { self.model = model }

    public var body: some View {
        GeometryReader { proxy in
            let scale = FaceSizer.scale(forHeight: proxy.size.height)
            Group {
                if model.isHalfTime {
                    halfTimeView(scale: scale)
                } else {
                    runningMatchView(scale: scale, width: proxy.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("glanceFace")
    }

    // MARK: - Constants
    private enum Constants {
        static let prominentScale: CGFloat = 1.1
        static let verticalSpacingBase: CGFloat = 4
        static let contentPaddingBase: CGFloat = 5
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
                    size: max(32, layout.iconButtonDiameter * scale),
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(max(0.92, scale * Constants.prominentScale), anchor: .center)
                    .padding(.vertical, theme.spacing.m * scale)
            }
        }
    }

    @ViewBuilder
    private func runningMatchView(scale: CGFloat, width: CGFloat) -> some View {
        let widthCap = layout.dimension(196, minimum: 156, maximum: 208)
        let rowWidth = min(width * 0.88, widthCap)
        VStack(spacing: Constants.verticalSpacingBase * scale) {
            Text(model.matchTime)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .scaleEffect(max(1.0, scale * Constants.prominentScale), anchor: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Match time")
                .accessibilityValue(model.matchTime)

            Text(model.periodTimeRemaining)
                .font(theme.typography.timerSecondary)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.accentSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .scaleEffect(max(0.94, scale * 0.98), anchor: .center)
                .padding(.vertical, max(1, theme.spacing.xs * 0.25 * scale))
                .padding(.horizontal, max(8, theme.spacing.s * scale))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time remaining")
                .accessibilityValue(model.periodTimeRemaining)
        }
        .padding(.vertical, Constants.contentPaddingBase * scale)
        .frame(maxWidth: rowWidth)
        .contentShape(Rectangle())
        .onTapGesture {
            haptics.play(.tap)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}

#Preview {
    GlanceTimerFace(model: MatchViewModel(haptics: NoopHaptics()))
        .hapticsProvider(NoopHaptics())
}
