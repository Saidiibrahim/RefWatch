//
//  DateFormatter+Common.swift
//  RefWatch Watch App
//
//  Description: Shared, cached date formatters for consistent and performant formatting.
//

import Foundation

extension DateFormatter {
    /// Short time style for watch UI (e.g., 9:41 AM), dateStyle = .none
    static let watchShortTime: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

