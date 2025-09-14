// ProStoppageFace.swift
// Advanced timer face emphasizing per-period context and stoppage

import SwiftUI
import WatchKit
import RefWatchCore

public struct ProStoppageFace: View {
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
                    color: Color.green,
                    size: max(32, Constants.iconSize * scale),
                    action: {
                        WKInterfaceDevice.current().play(.start)
                        model.startHalfTimeManually()
                    }
                )
                .padding(.bottom, 16 * scale)
                Spacer()
            } else {
                Text(model.halfTimeElapsed)
                    .font(.system(size: Constants.halfTimeLargeFontBase * scale, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.vertical, Constants.halfTimeVerticalPaddingBase * scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @ViewBuilder
    private func runningMatchView(scale: CGFloat, width: CGFloat) -> some View {
        let rowMaxWidth = min(width * 0.78, 180)
        return VStack(spacing: Constants.verticalSpacingBase * scale) {
            // Prominent per-period context: time remaining in current period
            Text(model.periodTimeRemaining)
                .font(.system(size: Constants.prominentFontBase * scale, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Elapsed row (total match time)
            HStack {
                Text("Elapsed")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Spacer()
                Text(model.matchTime)
                    .font(.system(size: Constants.rowValueFontBase * scale, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: rowMaxWidth)
            .frame(maxWidth: .infinity)

            // Stoppage row (dedicated tap target to toggle stoppage while running)
            HStack {
                Text("Stoppage")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Spacer()
                Text("+\(model.formattedStoppageTime)")
                    .font(.system(size: Constants.stoppageFontBase * scale, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(model.isInStoppage ? .orange : .gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: rowMaxWidth)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                WKInterfaceDevice.current().play(.click)
                // Only allow manual stoppage toggling while the period is running.
                guard model.isPaused == false else { return }
                if model.isInStoppage { model.endStoppage() } else { model.beginStoppage() }
            }
        }
        .padding(.vertical, Constants.contentVerticalPaddingBase * scale)
        .padding(.bottom, Constants.bottomInsetBase * scale)
        // Main face tap toggles pause/resume like the Standard face
        .onTapGesture {
            WKInterfaceDevice.current().play(.click)
            if model.isPaused { model.resumeMatch() } else { model.pauseMatch() }
        }
    }
}

#Preview {
    ProStoppageFace(model: MatchViewModel(haptics: WatchHaptics()))
}
