// FaceSizing.swift
// Utilities for adapting timer face content to available space

import SwiftUI

enum FaceSizer {
    /// Returns a scale factor for face content based on the available height
    /// of the face area inside the timer host. This adapts the layout across
    /// different watch sizes and host chrome while preserving legibility.
    static func scale(forHeight height: CGFloat) -> CGFloat {
        guard height.isFinite, height > 0 else { return 1.0 }
        // Calibrated thresholds for common watch sizes and varying host chrome
        // (period label, scores, page dots). Keeps a reasonable floor.
        switch height {
        case 140...: return 1.00
        case 130..<140: return 0.96
        case 120..<130: return 0.92
        case 112..<120: return 0.88
        default: return 0.82
        }
    }
}

