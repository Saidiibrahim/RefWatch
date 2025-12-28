//
//  CompletedMatch+Hashable.swift
//  RefWatchiOS
//
//  Provides Hashable/Equatable conformance for navigation routing by
//  comparing only the stable `id` of a CompletedMatch.
//

import Foundation
import RefWatchCore

extension CompletedMatch: Hashable {
    public static func == (lhs: CompletedMatch, rhs: CompletedMatch) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
