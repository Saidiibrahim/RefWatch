// StandardTimerFace.swift
// Extracted central timer UI matching current behavior

import SwiftUI
import RefWatchCore

public struct StandardTimerFace: View {
    @Environment(\.haptics) private var haptics
    @Environment(\.theme) private var theme
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
                size: 44,
                action: {
                    haptics.play(.resume)
                    model.startHalfTimeManually()
                }
            )
            .padding(.bottom, theme.spacing.l)
            Spacer()
        } else {
            Text(model.halfTimeElapsed)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)
                .padding(.vertical, theme.spacing.xl)
        }
    }

    @ViewBuilder
    private var runningMatchView: some View {
        VStack(spacing: theme.spacing.xs) {
            Text(model.matchTime)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary)

            Text(model.periodTimeRemaining)
                .font(theme.typography.timerSecondary)
                .foregroundStyle(theme.colors.textSecondary)

            if model.isInStoppage {
                Text("+\(model.formattedStoppageTime)")
                    .font(theme.typography.timerTertiary)
                    .foregroundStyle(theme.colors.matchWarning)
            }
        }
        .padding(.vertical, theme.spacing.s)
        .onTapGesture {
            haptics.play(.tap)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}
