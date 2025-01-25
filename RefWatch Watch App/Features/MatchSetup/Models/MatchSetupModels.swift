// Models for match setup phase
import Foundation

enum TeamType {
    case home, away
}

struct MatchSetupConfiguration {
    var duration: Int
    var periods: Int
    var halfTimeLength: Int
    var hasExtraTime: Bool
    var hasPenalties: Bool
    
    static let `default` = MatchSetupConfiguration(
        duration: 90,
        periods: 2,
        halfTimeLength: 15,
        hasExtraTime: false,
        hasPenalties: false
    )
} 