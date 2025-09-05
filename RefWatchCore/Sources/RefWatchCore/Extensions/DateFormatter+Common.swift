//
//  DateFormatter+Common.swift
//  RefWatchCore
//
//  Shared, cached date formatters for consistent and performant formatting.
//

import Foundation

public extension DateFormatter {
    /// Short time style for watch/iOS UI (e.g., 9:41 AM), dateStyle = .none
    public static let watchShortTime: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
