//
//  MatchSetupModels.swift
//  RefWatchCore
//
//  Models for match setup phase
//

import Foundation

public enum TeamType {
    case home, away
}

public struct MatchSetupConfiguration {
    public var duration: Int
    public var periods: Int
    public var halfTimeLength: Int
    public var hasExtraTime: Bool
    public var hasPenalties: Bool
    
    public init(duration: Int, periods: Int, halfTimeLength: Int, hasExtraTime: Bool, hasPenalties: Bool) {
        self.duration = duration
        self.periods = periods
        self.halfTimeLength = halfTimeLength
        self.hasExtraTime = hasExtraTime
        self.hasPenalties = hasPenalties
    }
    
    public static let `default` = MatchSetupConfiguration(
        duration: 90,
        periods: 2,
        halfTimeLength: 15,
        hasExtraTime: false,
        hasPenalties: false
    )
}

