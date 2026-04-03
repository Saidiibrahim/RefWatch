#if DEBUG
import Foundation
import RefWatchCore

@MainActor
func makeSampleCompletedMatch(
  homeTeam: String,
  awayTeam: String,
  homeScore: Int,
  awayScore: Int,
  hasEvents: Bool,
  events: [MatchEventRecord]? = nil,
  completedAt: Date = Date()) -> CompletedMatch
{
  var match = Match(homeTeam: homeTeam, awayTeam: awayTeam)
  match.homeScore = homeScore
  match.awayScore = awayScore

  let resolvedEvents = events ?? (hasEvents ? defaultSampleCompletedMatchEvents() : [])
  applyRecordTallies(from: resolvedEvents, to: &match)

  return CompletedMatch(
    completedAt: completedAt,
    match: match,
    events: resolvedEvents)
}

private func defaultSampleCompletedMatchEvents() -> [MatchEventRecord] {
  [
    generalEvent(time: "00:00", period: 1, eventType: .kickOff),
    goalEvent(
      time: "12:00",
      period: 1,
      team: .home,
      goalType: .regular,
      playerNumber: 9,
      playerName: "Alex Gray"),
    cardEvent(
      time: "27:00",
      period: 1,
      team: .home,
      cardType: .yellow,
      recipientType: .player,
      playerNumber: 6,
      playerName: "Sam Cole",
      reason: "USB",
      reasonTitle: "Unsporting Behaviour"),
    substitutionEvent(
      time: "41:00",
      period: 1,
      team: .home,
      playerOut: 4,
      playerOutName: "Jamie North",
      playerIn: 14,
      playerInName: "Taylor Reed"),
    generalEvent(time: "45:00", period: 1, eventType: .halfTime),
    goalEvent(
      time: "58:00",
      period: 2,
      team: .away,
      goalType: .penalty,
      playerNumber: 10,
      playerName: "Jordan Vale"),
    cardEvent(
      time: "64:00",
      period: 2,
      team: .away,
      cardType: .yellow,
      recipientType: .teamOfficial,
      officialRole: .coach,
      officialName: "Rowan Price",
      reason: "Dissent",
      reasonTitle: "Dissent"),
    cardEvent(
      time: "72:00",
      period: 2,
      team: .away,
      cardType: .red,
      recipientType: .player,
      playerNumber: 5,
      playerName: "Chris Lane",
      reason: "Second caution dismissal",
      reasonCode: "R7",
      reasonTitle: "Second Caution"),
    substitutionEvent(
      time: "81:00",
      period: 2,
      team: .away,
      playerOut: 7,
      playerOutName: "Leo West",
      playerIn: 18,
      playerInName: "Mason Hart"),
    goalEvent(
      time: "88:00",
      period: 2,
      team: .home,
      goalType: .freeKick,
      playerNumber: 11,
      playerName: "Kai Moore"),
    generalEvent(time: "90:00", period: 2, eventType: .matchEnd),
  ]
}

private func applyRecordTallies(from events: [MatchEventRecord], to match: inout Match) {
  match.homeYellowCards = 0
  match.awayYellowCards = 0
  match.homeRedCards = 0
  match.awayRedCards = 0
  match.homeSubs = 0
  match.awaySubs = 0

  for event in events {
    switch event.eventType {
    case let .card(details):
      switch (event.team, details.cardType) {
      case (.home?, .yellow):
        match.homeYellowCards += 1
      case (.away?, .yellow):
        match.awayYellowCards += 1
      case (.home?, .red):
        match.homeRedCards += 1
      case (.away?, .red):
        match.awayRedCards += 1
      case (nil, _):
        break
      }
    case .substitution:
      switch event.team {
      case .home?:
        match.homeSubs += 1
      case .away?:
        match.awaySubs += 1
      case nil:
        break
      }
    default:
      break
    }
  }
}

private func goalEvent(
  time: String,
  period: Int,
  team: TeamSide,
  goalType: GoalDetails.GoalType,
  playerNumber: Int?,
  playerName: String?) -> MatchEventRecord
{
  let details = GoalDetails(goalType: goalType, playerNumber: playerNumber, playerName: playerName)
  return MatchEventRecord(
    matchTime: time,
    period: period,
    eventType: .goal(details),
    team: team,
    details: .goal(details))
}

private func cardEvent(
  time: String,
  period: Int,
  team: TeamSide,
  cardType: CardDetails.CardType,
  recipientType: CardRecipientType,
  playerNumber: Int? = nil,
  playerName: String? = nil,
  officialRole: TeamOfficialRole? = nil,
  officialName: String? = nil,
  reason: String,
  reasonCode: String? = nil,
  reasonTitle: String? = nil) -> MatchEventRecord
{
  let details = CardDetails(
    cardType: cardType,
    recipientType: recipientType,
    playerNumber: playerNumber,
    playerName: playerName,
    officialRole: officialRole,
    officialName: officialName,
    reason: reason,
    reasonCode: reasonCode,
    reasonTitle: reasonTitle)
  return MatchEventRecord(
    matchTime: time,
    period: period,
    eventType: .card(details),
    team: team,
    details: .card(details))
}

private func substitutionEvent(
  time: String,
  period: Int,
  team: TeamSide,
  playerOut: Int?,
  playerOutName: String?,
  playerIn: Int?,
  playerInName: String?) -> MatchEventRecord
{
  let details = SubstitutionDetails(
    playerOut: playerOut,
    playerIn: playerIn,
    playerOutName: playerOutName,
    playerInName: playerInName)
  return MatchEventRecord(
    matchTime: time,
    period: period,
    eventType: .substitution(details),
    team: team,
    details: .substitution(details))
}

private func generalEvent(
  time: String,
  period: Int,
  eventType: MatchEventType) -> MatchEventRecord
{
  MatchEventRecord(
    matchTime: time,
    period: period,
    eventType: eventType,
    team: nil,
    details: .general)
}
#endif
