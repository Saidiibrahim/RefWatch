// TimerFaceStyle.swift
// Styles (variants) of timer faces the referee can choose from.

import Foundation

public enum TimerFaceStyle: String, CaseIterable, Identifiable {
    case standard

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        }
    }
}

