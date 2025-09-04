//
//  ConnectivitySyncProviding.swift
//  RefWatchCore
//
//  Abstraction for watch<->phone sync of match snapshots
//

import Foundation

public protocol ConnectivitySyncProviding {
    var isAvailable: Bool { get }
    func sendCompletedMatch(_ match: CompletedMatch)
}

