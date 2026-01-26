import Foundation

public enum AppMode: String, CaseIterable, Codable, Identifiable, Sendable, Hashable {
  case match

  public var id: String { rawValue }
  public var displayName: String { "Match" }
  public var systemImageName: String { "sportscourt" }
  public var tagline: String { "Officiate smarter" }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = (try? container.decode(String.self)) ?? AppMode.match.rawValue
    self = AppMode(rawValue: rawValue) ?? .match
  }
}
