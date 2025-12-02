//
//  MatchSetupViewModel.swift
//  RefWatchCore
//
//  ViewModel for match setup phase
//

import Foundation

@MainActor
public final class MatchSetupViewModel {
    public let matchViewModel: MatchViewModel
    public private(set) var selectedTab: Int = 1 // Start in middle tab
    
    public init(matchViewModel: MatchViewModel) {
        self.matchViewModel = matchViewModel
    }
    
    public func setSelectedTab(_ tab: Int) {
        selectedTab = tab
    }
    
    public func startMatch() {
        matchViewModel.startMatch()
    }
}
