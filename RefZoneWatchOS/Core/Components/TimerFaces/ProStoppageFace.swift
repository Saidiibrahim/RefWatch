// ProStoppageFace.swift
// Advanced timer face emphasizing per-period context and stoppage

import SwiftUI
import WatchKit
import RefWatchCore

public struct ProStoppageFace: View {
    let model: TimerFaceModel

    public init(model: TimerFaceModel) { self.model = model }

    public var body: some View {
        Group {
            if model.isHalfTime { halfTimeView } else { runningMatchView }
        }
        .accessibilityIdentifier("proStoppageFace")
    }

    // MARK: - Constants
    private enum Constants {
        static let prominentFontSize: CGFloat = 36
        static let iconSize: CGFloat = 44
        static let verticalSpacing: CGFloat = 6
        static let rowValueFontSize: CGFloat = 18
        static let stoppageFontSize: CGFloat = 16
        static let halfTimeLargeFontSize: CGFloat = 48
        static let halfTimeVerticalPadding: CGFloat = 40
        static let contentVerticalPadding: CGFloat = 8
    }

    // MARK: - Subviews
    @ViewBuilder
    private var halfTimeView: some View {
        if model.waitingForHalfTimeStart {
            Spacer()
            IconButton(
                icon: "checkmark.circle.fill",
                color: Color.green,
                size: Constants.iconSize,
                action: {
                    WKInterfaceDevice.current().play(.start)
                    model.startHalfTimeManually()
                }
            )
            .padding(.bottom, 20)
            Spacer()
        } else {
            Text(model.halfTimeElapsed)
                .font(.system(size: Constants.halfTimeLargeFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .padding(.vertical, Constants.halfTimeVerticalPadding)
        }
    }

    @ViewBuilder
    private var runningMatchView: some View {
        VStack(spacing: Constants.verticalSpacing) {
            // Prominent per-period context: time remaining in current period
            Text(model.periodTimeRemaining)
                .font(.system(size: Constants.prominentFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()

            // Elapsed row (total match time)
            HStack {
                Text("Elapsed")
                    .foregroundColor(.gray)
                Spacer()
                Text(model.matchTime)
                    .font(.system(size: Constants.rowValueFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }

            // Stoppage row
            HStack {
                Text("Stoppage")
                    .foregroundColor(.gray)
                Spacer()
                Text("+\(model.formattedStoppageTime)")
                    .font(.system(size: Constants.stoppageFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(model.isInStoppage ? .orange : .gray)
            }
        }
        .padding(.vertical, Constants.contentVerticalPadding)
        .onTapGesture {
            WKInterfaceDevice.current().play(.click)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}

#Preview {
    ProStoppageFace(model: MatchViewModel(haptics: WatchHaptics()))
}
