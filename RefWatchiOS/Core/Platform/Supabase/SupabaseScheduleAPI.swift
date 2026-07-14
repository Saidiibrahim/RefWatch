import Foundation
import RefWatchCore

protocol ScheduleRemoteServing {
  func fetchScheduledMatches(
    ownerId: UUID,
    updatedAfter: Date?) async throws -> [ScheduleRemoteContract.RemoteScheduledMatch]
  func syncScheduledMatch(
    _ request: ScheduleRemoteContract.UpsertRequest) async throws -> ScheduleRemoteContract.SyncResult
  func deleteScheduledMatch(id: UUID) async throws
}

/// Portable schedule sync contract. Remote I/O is implemented by
/// `BackendScheduleRepositoryAPI`; this type contains only shared DTOs.
struct ScheduleRemoteContract {
  struct RemoteScheduledMatch: Equatable {
    let id: UUID
    let ownerId: UUID
    let homeTeamName: String
    let awayTeamName: String
    let kickoffAt: Date
    let status: ScheduledMatch.Status
    let competitionId: UUID?
    let competitionName: String?
    let venueId: UUID?
    let venueName: String?
    let homeTeamId: UUID?
    let awayTeamId: UUID?
    let homeMatchSheet: ScheduledMatchSheet?
    let awayMatchSheet: ScheduledMatchSheet?
    let notes: String?
    let sourceDeviceId: String?
    let createdAt: Date
    let updatedAt: Date
    var deletedAt: Date? = nil
  }

  struct UpsertRequest: Equatable {
    let id: UUID
    let ownerId: UUID
    let homeTeamName: String
    let awayTeamName: String
    let kickoffAt: Date
    let status: ScheduledMatch.Status
    let competitionId: UUID?
    let competitionName: String?
    let venueId: UUID?
    let venueName: String?
    let homeTeamId: UUID?
    let awayTeamId: UUID?
    let homeMatchSheet: ScheduledMatchSheet?
    let awayMatchSheet: ScheduledMatchSheet?
    let notes: String?
    let sourceDeviceId: String?
  }

  struct SyncResult: Equatable {
    let updatedAt: Date
  }

  enum APIError: Error, Equatable {
    case invalidResponse
  }
}

extension ScheduleRemoteContract {
  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoWithoutFraction = ISO8601DateFormatter()
    isoWithoutFraction.formatOptions = [.withInternetDateTime]

    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      if let date = parseTimestamp(
        value,
        isoWithFraction: isoWithFraction,
        isoWithoutFraction: isoWithoutFraction)
      {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid date string: \(value)")
    }
    return decoder
  }

  static func decodeUpsertResponse(data: Data, decoder: JSONDecoder) throws -> [ScheduledMatchRowDTO] {
    if data.isEmpty { return [] }
    if let rows = try? decoder.decode([ScheduledMatchRowDTO].self, from: data) {
      return rows
    }
    struct Representation: Decodable { let data: [ScheduledMatchRowDTO] }
    if let wrapped = try? decoder.decode(Representation.self, from: data) {
      return wrapped.data
    }
    throw APIError.invalidResponse
  }

  private static func parseTimestamp(
    _ value: String,
    isoWithFraction: ISO8601DateFormatter,
    isoWithoutFraction: ISO8601DateFormatter) -> Date?
  {
    if let date = isoWithFraction.date(from: value) ?? isoWithoutFraction.date(from: value) {
      return date
    }
    let normalized = normalizeDatabaseTimestamp(value)
    return isoWithFraction.date(from: normalized) ?? isoWithoutFraction.date(from: normalized)
  }

  private static func normalizeDatabaseTimestamp(_ value: String) -> String {
    var result = value
    if let spaceIndex = result.firstIndex(of: " ") {
      result.replaceSubrange(spaceIndex...spaceIndex, with: "T")
    }
    guard let timezoneIndex = result.lastIndex(where: { $0 == "+" || $0 == "-" }) else {
      return result
    }
    let prefix = String(result[..<timezoneIndex])
    let suffix = String(result[timezoneIndex...])
    if suffix.contains(":") { return prefix + suffix }
    if suffix.count == 3 { return prefix + suffix + ":00" }
    if suffix.count == 5 {
      return prefix + suffix.prefix(3) + ":" + suffix.suffix(2)
    }
    return prefix + suffix
  }
}

struct ScheduledMatchRowDTO: Decodable, Sendable {
  let id: UUID
  let ownerId: UUID
  let homeTeamName: String
  let awayTeamName: String
  let homeTeamId: UUID?
  let awayTeamId: UUID?
  let homeMatchSheet: ScheduledMatchSheet?
  let awayMatchSheet: ScheduledMatchSheet?
  let kickoffAt: Date
  let status: String
  let competitionId: UUID?
  let competitionName: String?
  let venueId: UUID?
  let venueName: String?
  let notes: String?
  let sourceDeviceId: String?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case homeTeamName = "home_team_name"
    case awayTeamName = "away_team_name"
    case homeTeamId = "home_team_id"
    case awayTeamId = "away_team_id"
    case homeMatchSheet = "home_match_sheet"
    case awayMatchSheet = "away_match_sheet"
    case kickoffAt = "kickoff_at"
    case status
    case competitionId = "competition_id"
    case competitionName = "competition_name"
    case venueId = "venue_id"
    case venueName = "venue_name"
    case notes
    case sourceDeviceId = "source_device_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
