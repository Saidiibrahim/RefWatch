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
        Group {
            if model.isHalfTime { halfTimeView } else { runningMatchView }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private var halfTimeView: some View {
        if model.waitingForHalfTimeStart {
            Spacer()
            IconButton(
                icon: "checkmark.circle.fill",
                color: theme.colors.matchPositive,
                action: {
                    haptics.play(.resume)
                    model.startHalfTimeManually()
                }
            )
            .padding(.bottom, layout.dimension(theme.spacing.m, minimum: theme.spacing.s))
            Spacer()
        } else {
            Text(model.halfTimeElapsed)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, layout.dimension(theme.spacing.l, minimum: theme.spacing.m))
        }
    }

    @ViewBuilder
    private var runningMatchView: some View {
        let mainScale = max(1.03, layout.scale * 1.08)
        let remainingScale = max(1.02, layout.scale * 1.05)
        let stoppageScale = max(1.02, layout.scale * 1.06)

        VStack(spacing: layout.dimension(theme.spacing.xs, minimum: theme.spacing.xs * 0.75)) {
            Text(model.matchTime)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .scaleEffect(mainScale, anchor: .center)

            Text(model.periodTimeRemaining)
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .scaleEffect(remainingScale, anchor: .center)

            if model.isInStoppage {
                Text("+\(model.formattedStoppageTime)")
                    .font(theme.typography.timerTertiary)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.matchWarning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .scaleEffect(stoppageScale, anchor: .center)
            }
        }
        .padding(.vertical, layout.dimension(theme.spacing.s, minimum: theme.spacing.xs))
        .onTapGesture {
            haptics.play(.tap)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}
