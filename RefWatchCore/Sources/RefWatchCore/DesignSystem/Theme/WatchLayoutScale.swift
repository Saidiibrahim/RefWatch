import SwiftUI
#if os(watchOS)
import WatchKit
#endif

public enum WatchDisplayCategory: Equatable {
    case compact
    case standard
    case expanded

    #if os(watchOS)
    public static var current: WatchDisplayCategory {
        let height = WKInterfaceDevice.current().screenBounds.height
        switch height {
        case ..<431: return .compact
        case ..<492: return .standard
        default: return .expanded
        }
    }
    #else
    public static var current: WatchDisplayCategory { .standard }
    #endif
}

public struct WatchLayoutScale {
    public let category: WatchDisplayCategory
    public let scale: CGFloat
    public let safeAreaBottomPadding: CGFloat
    public let timerTopPadding: CGFloat
    public let timerBottomPadding: CGFloat

    public init(category: WatchDisplayCategory = .current) {
        self.category = category
        switch category {
        case .compact:
            self.scale = 0.88
            self.safeAreaBottomPadding = 8
            self.timerTopPadding = 8
            self.timerBottomPadding = 10
        case .standard:
            self.scale = 1.0
            self.safeAreaBottomPadding = 12
            self.timerTopPadding = 12
            self.timerBottomPadding = 14
        case .expanded:
            self.scale = 1.08
            self.safeAreaBottomPadding = 14
            self.timerTopPadding = 14
            self.timerBottomPadding = 18
        }
    }

    public func dimension(_ base: CGFloat, minimum: CGFloat? = nil, maximum: CGFloat? = nil) -> CGFloat {
        var value = base * scale
        if let minimum, value < minimum { value = minimum }
        if let maximum, value > maximum { value = maximum }
        return value
    }

    public var eventButtonSize: CGFloat {
        dimension(60, minimum: 52)
    }

    public var eventIconSize: CGFloat {
        dimension(24, minimum: 20, maximum: 28)
    }

    public var compactTeamTileHeight: CGFloat {
        dimension(60, minimum: 52)
    }

    public var teamScoreBoxHeight: CGFloat {
        dimension(74, minimum: 64)
    }

    public var iconButtonDiameter: CGFloat {
        dimension(42, minimum: 36)
    }

    public var penaltyPanelMinHeight: CGFloat {
        dimension(96, minimum: 84)
    }

    public var canFitEventGrid: Bool {
        switch category {
        case .compact: return false
        case .standard, .expanded: return true
        }
    }

    public var eventGridColumns: Int {
        switch category {
        case .compact: return 2
        case .standard, .expanded: return 2
        }
    }

    public var eventButtonLayout: EventButtonLayout {
        switch category {
        case .compact: return .compactVertical
        case .standard: return .standardGrid
        case .expanded: return .expandedGrid
        }
    }

    public var workoutArtworkSize: CGFloat {
        dimension(112, minimum: 92)
    }

    public var workoutTransportSmallDiameter: CGFloat {
        dimension(42, minimum: 36)
    }

    public var workoutTransportLargeDiameter: CGFloat {
        dimension(56, minimum: 48)
    }
}

public enum EventButtonLayout {
    case compactVertical
    case standardGrid
    case expandedGrid
}

private struct WatchLayoutScaleKey: EnvironmentKey {
    static let defaultValue = WatchLayoutScale()
}

public extension EnvironmentValues {
    var watchLayoutScale: WatchLayoutScale {
        get { self[WatchLayoutScaleKey.self] }
        set { self[WatchLayoutScaleKey.self] = newValue }
    }
}

public extension View {
    func watchLayoutScale(_ scale: WatchLayoutScale) -> some View {
        environment(\.watchLayoutScale, scale)
    }
}
