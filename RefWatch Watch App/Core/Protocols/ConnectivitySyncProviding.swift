//
//  ConnectivitySyncProviding.swift
//  Abstraction for watch<->phone sync of match snapshots
//

import Foundation

protocol ConnectivitySyncProviding {
    var isAvailable: Bool { get }
    func sendCompletedMatch(_ match: CompletedMatch)
}
