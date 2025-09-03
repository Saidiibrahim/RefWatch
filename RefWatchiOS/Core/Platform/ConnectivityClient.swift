//
//  ConnectivityClient.swift
//  RefWatchiOS
//
//  Very thin WatchConnectivity façade with graceful no-op fallback.
//  For this scaffold it exposes booleans and stubs used by the UI.
//

import Foundation
#if canImport(OSLog)
import OSLog
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

protocol ConnectivityProviding {
    var isSupported: Bool { get }
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    func sendFixtureSummary(home: String, away: String, when: String)
}

final class ConnectivityClient: ConnectivityProviding {
    static let shared = ConnectivityClient()

    #if canImport(WatchConnectivity)
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    #endif

    #if canImport(OSLog)
    private let logger = Logger(subsystem: "com.refwatch.app", category: "Connectivity")
    #endif

    var isSupported: Bool {
        #if canImport(WatchConnectivity)
        return WCSession.isSupported()
        #else
        return false
        #endif
    }

    var isPaired: Bool {
        #if canImport(WatchConnectivity)
        return session?.isPaired ?? false
        #else
        return false
        #endif
    }

    var isWatchAppInstalled: Bool {
        #if canImport(WatchConnectivity)
        return session?.isWatchAppInstalled ?? false
        #else
        return false
        #endif
    }

    var isReachable: Bool {
        #if canImport(WatchConnectivity)
        return session?.isReachable ?? false
        #else
        return false
        #endif
    }

    func sendFixtureSummary(home: String, away: String, when: String) {
        #if canImport(WatchConnectivity)
        guard let session = session else { return }

        guard isValid(team: home), isValid(team: away), isValid(when: when) else {
            #if canImport(OSLog)
            logger.warning("Rejected fixture payload due to validation failure")
            #endif
            return
        }

        guard session.isReachable else {
            #if canImport(OSLog)
            logger.info("WCSession not reachable; cannot send message")
            #endif
            return
        }

        let payload: [String: Any] = [
            "type": "fixture",
            "home": home.trimmingCharacters(in: .whitespacesAndNewlines),
            "away": away.trimmingCharacters(in: .whitespacesAndNewlines),
            "when": when.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        session.sendMessage(payload, replyHandler: nil) { [weak self] error in
            #if canImport(OSLog)
            self?.logger.error("sendMessage failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        #else
        // No-op in environments without WatchConnectivity.
        #endif
    }

    // MARK: - Validation
    private func isValid(team: String) -> Bool {
        let trimmed = team.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
        return CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-&'.")).isSuperset(of: CharacterSet(charactersIn: trimmed))
    }

    private func isValid(when: String) -> Bool {
        let trimmed = when.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 60
    }
}
