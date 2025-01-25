// ViewModel for match setup phase
import Foundation
import Observation

@Observable
final class MatchSetupViewModel {
    let matchViewModel: MatchViewModel
    private(set) var selectedTab: Int = 1 // Start in middle tab
    
    init(matchViewModel: MatchViewModel) {
        self.matchViewModel = matchViewModel
    }
    
    func setSelectedTab(_ tab: Int) {
        selectedTab = tab
    }
    
    func startMatch() {
        matchViewModel.startMatch()
    }
} 