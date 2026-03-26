// AlwaysOnTimerView.swift
// Simplified timer display for Always-On Display (reduced luminance)

import SwiftUI
import RefWatchCore

struct AlwaysOnTimerView: View {
    struct DisplayContent: Equatable {
        let headerText: String?
        let primaryTime: String
        let secondaryTime: String?
        let accessibilityLabel: String
        let accessibilityValue: String
    }

    @Environment(\.theme) private var theme
    let model: TimerFaceModel
    let scale: CGFloat

    static func displayContent(for model: any TimerFaceModelState) -> DisplayContent {
        if model.pendingPeriodBoundaryDecision != nil {
            let stoppage = model.formattedStoppageTime == "00:00" ? nil : "+\(model.formattedStoppageTime)"
            return DisplayContent(
                headerText: "EXP",
                primaryTime: model.matchTime,
                secondaryTime: stoppage,
                accessibilityLabel: "Time expired",
                accessibilityValue: stoppage.map { "\(model.matchTime), \($0)" } ?? model.matchTime
            )
        }

        if model.isHalfTime {
            return DisplayContent(
                headerText: "HT",
                primaryTime: model.halfTimeElapsed,
                secondaryTime: nil,
                accessibilityLabel: "Half time",
                accessibilityValue: model.halfTimeElapsed
            )
        }

        if model.waitingForHalfTimeStart {
            return DisplayContent(
                headerText: "HT",
                primaryTime: model.matchTime,
                secondaryTime: nil,
                accessibilityLabel: "Half time",
                accessibilityValue: model.matchTime
            )
        }

        return DisplayContent(
            headerText: nil,
            primaryTime: model.matchTime,
            secondaryTime: model.periodTimeRemaining,
            accessibilityLabel: "Match time",
            accessibilityValue: model.matchTime
        )
    }

    var body: some View {
        let content = Self.displayContent(for: model)
        VStack(spacing: 6 * scale) {
            if let headerText = content.headerText {
                Text(headerText)
                    .font(theme.typography.timerSecondary)
                    .foregroundStyle(theme.colors.textPrimary.opacity(0.5))
                    .scaleEffect(scale, anchor: .center)
            }

            Text(content.primaryTime)
                .font(theme.typography.timerPrimary)
                .foregroundStyle(theme.colors.textPrimary.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .scaleEffect(content.secondaryTime == nil ? scale : max(1.0, scale * 1.05), anchor: .center)

            if let secondaryTime = content.secondaryTime {
                Text(secondaryTime)
                    .font(theme.typography.timerSecondary)
                    .foregroundStyle(theme.colors.accentSecondary.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(max(0.9, scale * 0.95), anchor: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityValue(content.accessibilityValue)
    }
}

#Preview("Always-On Timer - Running") {
    AlwaysOnTimerView(model: MatchViewModel.previewRunningRegulation(), scale: 1)
        .watchFacePreviewSurface()
}

#Preview("Always-On Timer - Time Expired") {
    AlwaysOnTimerView(model: MatchViewModel.previewExpiredBoundary(), scale: 1)
        .watchFacePreviewSurface(layout: WatchPreviewSupport.compactLayout)
}

#Preview("Always-On Timer - Time Expired + Stoppage") {
    AlwaysOnTimerView(model: MatchViewModel.previewExpiredBoundary(stoppage: true), scale: 1)
        .watchFacePreviewSurface(layout: WatchPreviewSupport.compactLayout)
}

#Preview("Always-On Timer - Waiting For Half-Time") {
    AlwaysOnTimerView(model: MatchViewModel.previewWaitingForHalfTimeStart(), scale: 1)
        .watchFacePreviewSurface(layout: WatchPreviewSupport.compactLayout)
}

#Preview("Always-On Timer - Half-Time Elapsed") {
    AlwaysOnTimerView(model: MatchViewModel.previewHalfTimeActive(), scale: 1)
        .watchFacePreviewSurface()
}
