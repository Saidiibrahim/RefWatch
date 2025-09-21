import SwiftUI

public extension ColorPalette {
    func color(for eventType: MatchEventType) -> Color {
        switch eventType {
        case .goal:
            return matchPositive
        case .card(let details):
            return details.cardType == .yellow ? matchWarning : matchCritical
        case .substitution:
            return accentSecondary
        case .kickOff, .periodStart:
            return accentPrimary
        case .halfTime:
            return matchNeutral
        case .periodEnd, .matchEnd:
            return matchCritical
        case .penaltiesStart:
            return accentMuted
        case .penaltyAttempt(let details):
            return details.result == .scored ? matchPositive : matchCritical
        case .penaltiesEnd:
            return matchPositive
        }
    }

    func badgeColor(for team: TeamSide?) -> Color {
        guard let team else { return surfaceOverlay }
        switch team {
        case .home:
            return accentPrimary
        case .away:
            return accentMuted
        }
    }
}
