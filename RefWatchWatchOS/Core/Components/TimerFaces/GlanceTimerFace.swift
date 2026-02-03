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
                    runningMatchView(scale: scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("glanceFace")
    }

    // MARK: - Constants
    private enum Constants {
        static let prominentScale: CGFloat = 1.15
        static let verticalSpacingBase: CGFloat = 4
        static let contentPaddingBase: CGFloat = 6
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
                    .scaleEffect(scale * Constants.prominentScale, anchor: .center)
                    .padding(.vertical, theme.spacing.m * scale)
            }
        }
    }

    @ViewBuilder
    private func runningMatchView(scale: CGFloat) -> some View {
        VStack(spacing: Constants.verticalSpacingBase * scale) {
            Text(model.matchTime)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .scaleEffect(scale * Constants.prominentScale, anchor: .center)

            Text(model.periodTimeRemaining)
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .scaleEffect(scale, anchor: .center)
        }
        .padding(.vertical, Constants.contentPaddingBase * scale)
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
