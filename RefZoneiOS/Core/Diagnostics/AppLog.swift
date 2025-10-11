//
//  AppLog.swift
//  RefZoneiOS
//
//  Centralized OSLog helpers for consistent logging across features.
//

import Foundation
#if canImport(OSLog)
import OSLog
#endif

enum AppLog {
    #if canImport(OSLog)
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.refwatch.app"
    static let history = Logger(subsystem: subsystem, category: "History")
    static let schedule = Logger(subsystem: subsystem, category: "Schedule")
    static let library = Logger(subsystem: subsystem, category: "Library")
    static let connectivity = Logger(subsystem: subsystem, category: "Connectivity")
    static let supabase = Logger(subsystem: subsystem, category: "Supabase")
#else
    // Fallback no-op stubs when OSLog is unavailable
    struct NoopLogger {
        func info(_ message: String) {}
        func warning(_ message: String) {}
        func error(_ message: String) {}
    }
    static let history = NoopLogger()
    static let schedule = NoopLogger()
    static let library = NoopLogger()
    static let connectivity = NoopLogger()
    static let supabase = NoopLogger()
#endif
}
