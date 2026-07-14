import Foundation

enum BackendQuery {
  static func updatedAfter(_ date: Date?) -> [URLQueryItem] {
    guard let date else { return [] }
    return [URLQueryItem(name: "updatedAfter", value: ISO8601DateFormatter().string(from: date))]
  }
}
