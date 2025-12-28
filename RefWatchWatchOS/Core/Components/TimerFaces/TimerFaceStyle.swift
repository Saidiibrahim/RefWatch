// TimerFaceStyle.swift
// Styles (variants) of timer faces the referee can choose from.

import Foundation

public enum TimerFaceStyle: String, CaseIterable, Identifiable {
    case standard
    case proStoppage

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .proStoppage: return "Pro Stoppage"
        }
    }

    /// Safely parse a stored raw value into a face style.
    /// Falls back to `.standard` for nil/unknown values to avoid crashes or undefined UI.
    public static func parse(raw: String?) -> TimerFaceStyle {
        guard let raw, let style = TimerFaceStyle(rawValue: raw) else { return .standard }
        return style
    }
}
