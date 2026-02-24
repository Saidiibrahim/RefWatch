// StandardTimerFace.swift
// Extracted central timer UI matching current behavior

import SwiftUI
import RefWatchCore

public struct StandardTimerFace: View {
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
        .accessibilityIdentifier("standardFace")
    }

    // MARK: - Constants
    private enum Constants {
        static let groupSpacingBase: CGFloat = 4
        static let contentPaddingBase: CGFloat = 4
    }

    // MARK: - Subviews
    @ViewBuilder
    private func halfTimeView(scale: CGFloat) -> some View {
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
            .padding(.bottom, max(theme.spacing.s, layout.dimension(theme.spacing.m) * scale))
            Spacer()
        } else {
            Text(model.halfTimeElapsed)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .scaleEffect(max(0.9, scale * 1.05), anchor: .center)
                .padding(.vertical, max(theme.spacing.m, layout.dimension(theme.spacing.l) * scale))
        }
    }

    @ViewBuilder
    private func runningMatchView(scale: CGFloat, width: CGFloat) -> some View {
        let mainScale = max(1.0, scale * 1.08)
        let remainingScale = max(0.94, scale * 0.98)
        let stoppageScale = max(0.9, scale * 0.96)
        let rowWidth = min(width * 0.86, 186)

        VStack(spacing: Constants.groupSpacingBase * scale) {
            Text(model.matchTime)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .scaleEffect(mainScale, anchor: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Match time")
                .accessibilityValue(model.matchTime)

            Text(model.periodTimeRemaining)
                .font(theme.typography.timerSecondary)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.accentSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .scaleEffect(remainingScale, anchor: .center)
                .padding(.vertical, max(1, theme.spacing.xs * 0.28 * scale))
                .padding(.horizontal, max(8, theme.spacing.s * scale))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time remaining")
                .accessibilityValue(model.periodTimeRemaining)

            if model.isInStoppage {
                Text("+\(model.formattedStoppageTime)")
                    .font(theme.typography.timerTertiary)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.matchWarning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(stoppageScale, anchor: .center)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Stoppage time")
                    .accessibilityValue("+\(model.formattedStoppageTime)")
            }
        }
        .frame(maxWidth: rowWidth)
        .padding(.vertical, Constants.contentPaddingBase * scale)
        .contentShape(Rectangle())
        .onTapGesture {
            haptics.play(.tap)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}
