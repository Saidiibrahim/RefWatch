import Foundation

protocol ReferenceCatalogServing: AnyObject {
  func fetchReferenceTeams(seasonYear: Int) async throws -> [ReferenceTeamOption]
  func fetchReferenceCompetitions(seasonYear: Int) async throws -> [ReferenceCompetitionOption]
}

enum ReferenceCatalogServiceError: LocalizedError {
  case backendUnavailable

  var errorDescription: String? {
    switch self {
    case .backendUnavailable:
      return "The authenticated reference catalog service is unavailable."
    }
  }
}

final class BackendReferenceCatalogService: ReferenceCatalogServing {
  private struct TeamResponse: Decodable {
    let id: UUID
    let referenceKey: String
    let name: String
    let shortName: String?
    let competitionCode: String
    let competitionName: String

    enum CodingKeys: String, CodingKey {
      case id
      case referenceKey = "reference_key"
      case name
      case shortName = "short_name"
      case competitionCode = "competition_code"
      case competitionName = "competition_name"
    }
  }

  private struct CompetitionResponse: Decodable {
    let id: UUID
    let code: String
    let name: String
  }

  private let client: BackendAPIClient

  init(client: BackendAPIClient) {
    self.client = client
  }

  func fetchReferenceTeams(seasonYear: Int) async throws -> [ReferenceTeamOption] {
    let rows: [TeamResponse] = try await client.send(
      path: "/api/reference-catalog/teams",
      queryItems: [URLQueryItem(name: "seasonYear", value: String(seasonYear))])
    return rows.map {
      ReferenceTeamOption(
        id: $0.id,
        referenceKey: $0.referenceKey,
        name: $0.name,
        shortName: $0.shortName,
        competitionCode: $0.competitionCode,
        competitionName: $0.competitionName)
    }
  }

  func fetchReferenceCompetitions(seasonYear: Int) async throws -> [ReferenceCompetitionOption] {
    let rows: [CompetitionResponse] = try await client.send(
      path: "/api/reference-catalog/competitions",
      queryItems: [URLQueryItem(name: "seasonYear", value: String(seasonYear))])
    return rows.map { ReferenceCompetitionOption(id: $0.id, code: $0.code, name: $0.name) }
  }
}
