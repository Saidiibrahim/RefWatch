// ProStoppageFace.swift
// Advanced timer face emphasizing per-period context and stoppage

import SwiftUI
import WatchKit

public struct ProStoppageFace: View {
    let model: TimerFaceModel

    public init(model: TimerFaceModel) { self.model = model }

    public var body: some View {
        Group {
            if model.isHalfTime { halfTimeView } else { runningMatchView }
        }
        .accessibilityIdentifier("proStoppageFace")
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
                    WKInterfaceDevice.current().play(.start)
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
        VStack(spacing: 6) {
            // Prominent per-period context: time remaining in current period
            Text(model.periodTimeRemaining)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            // Elapsed row (total match time)
            HStack {
                Text("Elapsed")
                    .foregroundColor(.gray)
                Spacer()
                Text(model.matchTime)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }

            // Stoppage row
            HStack {
                Text("Stoppage")
                    .foregroundColor(.gray)
                Spacer()
                Text("+\(model.formattedStoppageTime)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(model.isInStoppage ? .orange : .gray)
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            WKInterfaceDevice.current().play(.click)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}

