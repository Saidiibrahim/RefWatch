import Foundation

struct BackendEnvironment: Equatable {
  enum ConfigurationError: LocalizedError, Equatable {
    case missingValue(key: String)
    case unresolvedPlaceholder(key: String)
    case invalidBaseURL(String)

    var errorDescription: String? {
      switch self {
      case let .missingValue(key):
        "Missing configuration value for '\(key)'."
      case let .unresolvedPlaceholder(key):
        "Configuration value for '\(key)' contains an unresolved build setting."
      case let .invalidBaseURL(value):
        "Backend API base URL is invalid: '\(value)'."
      }
    }
  }

  let baseURL: URL
  let clerkPublishableKey: String

  static func load(
    infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
    processEnvironment: [String: String] = ProcessInfo.processInfo.environment) throws -> BackendEnvironment
  {
    let rawURL = try resolve(
      key: "BACKEND_API_BASE_URL",
      infoDictionary: infoDictionary,
      processEnvironment: processEnvironment)
    let publishableKey = try resolve(
      key: "CLERK_PUBLISHABLE_KEY",
      infoDictionary: infoDictionary,
      processEnvironment: processEnvironment)

    let trimmedURL = sanitize(rawURL)
    let trimmedKey = sanitize(publishableKey)
    guard trimmedURL.contains("$(") == false else {
      throw ConfigurationError.unresolvedPlaceholder(key: "BACKEND_API_BASE_URL")
    }
    guard trimmedKey.contains("$(") == false else {
      throw ConfigurationError.unresolvedPlaceholder(key: "CLERK_PUBLISHABLE_KEY")
    }
    guard let url = URL(string: trimmedURL),
          ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
          url.host?.isEmpty == false
    else {
      throw ConfigurationError.invalidBaseURL(trimmedURL)
    }
    return BackendEnvironment(baseURL: url, clerkPublishableKey: trimmedKey)
  }

  private static func resolve(
    key: String,
    infoDictionary: [String: Any]?,
    processEnvironment: [String: String]) throws -> String
  {
    if let value = infoDictionary?[key] as? String, value.isEmpty == false { return value }
    if let value = processEnvironment[key], value.isEmpty == false { return value }
    throw ConfigurationError.missingValue(key: key)
  }

  private static func sanitize(_ value: String) -> String {
    var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if result.hasPrefix("\""), result.hasSuffix("\""), result.count > 1 {
      result.removeFirst()
      result.removeLast()
    }
    return result
  }
}
