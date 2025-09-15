// StandardTimerFace.swift
// Extracted central timer UI matching current behavior

import SwiftUI

public struct StandardTimerFace: View {
    @Environment(\.haptics) private var haptics
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
                color: Color.green,
                size: 44,
                action: {
                    haptics.play(.resume)
                    model.startHalfTimeManually()
                }
            )
            .padding(.bottom, 20)
            Spacer()
        } else {
            Text(model.halfTimeElapsed)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .padding(.vertical, 40)
        }
    }

    @ViewBuilder
    private var runningMatchView: some View {
        VStack(spacing: 4) {
            Text(model.matchTime)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(model.periodTimeRemaining)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.gray)

            if model.isInStoppage {
                Text("+\(model.formattedStoppageTime)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            haptics.play(.tap)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}
