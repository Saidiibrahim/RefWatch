//
//  SupabaseEnvironment.swift
//  RefWatchiOS
//
//  Lightweight loader that resolves Supabase configuration from Info.plist
//  placeholders or environment variables. Keeping this isolated lets us
//  evolve how the app supplies secrets without touching call sites.
//

import Foundation
internal import os

private struct ResolvedValue {
  enum Source: String {
    case infoDictionary
    case processEnvironment

    var description: String { rawValue }
  }

  let key: String
  let value: String
  let source: Source
}

struct SupabaseEnvironment {
  enum ConfigurationError: Error, LocalizedError, Equatable {
    case missingValue(key: String)
    case unresolvedPlaceholder(key: String)
    case invalidURL(String)

    var errorDescription: String? {
      switch self {
      case let .missingValue(key):
        "Missing configuration value for '\(key)'. " +
          "Check your Secrets.xcconfig file and ensure it contains a valid value for this key."
      case let .unresolvedPlaceholder(key):
        "Configuration value for '\(key)' contains an unresolved placeholder " +
          "like '$(VARIABLE_NAME)'. This usually means:\n" +
          "1. The Secrets.xcconfig file is missing or not properly configured\n" +
          "2. The xcconfig file is not included in your Xcode project\n" +
          "3. Build settings are not properly configured\n" +
          "Please check your project configuration and ensure Secrets.xcconfig exists " +
          "with valid values."
      case let .invalidURL(rawValue):
        "Supabase URL is invalid: '\(rawValue)'. The URL must be a valid absolute URL " +
          "with both a scheme (http/https) and a host (e.g., 'https://yourproject.supabase.co'). " +
          "Check your SUPABASE_URL configuration in Secrets.xcconfig."
      }
    }

    var recoverySuggestion: String? {
      switch self {
      case let .missingValue(key):
        "Add a valid value for '\(key)' to your Secrets.xcconfig file. " +
          "You can copy from Secrets.example.xcconfig as a template."
      case .unresolvedPlaceholder:
        "Create or update your Secrets.xcconfig file with proper values. " +
          "Ensure the file is included in your Xcode project and build settings."
      case .invalidURL:
        "Verify your SUPABASE_URL in Secrets.xcconfig follows the format: https://yourproject.supabase.co"
      }
    }
  }

  let url: URL
  let anonKey: String

  /// Attempts to build the environment from the app bundle or process env.
  /// Priority: Info.plist value (if non-empty and resolved) → process env → error.
  static func load(
    infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
    environment: [String: String] = ProcessInfo.processInfo.environment) throws -> SupabaseEnvironment
  {
    AppLog.supabase.info("Loading Supabase environment configuration...")

    do {
      // Resolve and sanitize raw URL value from Info.plist or env. Trimming helps
      // avoid subtle crashes if values accidentally include whitespace/newlines.
      let rawURL = try resolveValue(
        key: "SUPABASE_URL",
        infoDictionary: infoDictionary,
        environment: environment)

      // Check for unresolved placeholder before processing
      if rawURL.value.contains("$(") {
        AppLog.supabase.error("SUPABASE_URL contains unresolved placeholder: \(rawURL.value, privacy: .public)")
        throw ConfigurationError.unresolvedPlaceholder(key: "SUPABASE_URL")
      }

      // Trim whitespace and optional surrounding quotes from xcconfig values
      var urlString = rawURL.value.trimmingCharacters(in: .whitespacesAndNewlines)
      if urlString.hasPrefix("\""), urlString.hasSuffix("\""), urlString.count > 1 {
        urlString.removeFirst()
        urlString.removeLast()
      }

      AppLog.supabase.info("Processed SUPABASE_URL: \(urlString, privacy: .public)")

      // Validate absolute URL with both scheme and a non-empty host. The SDK's
      // client initializer force-unwraps `.host` to derive a storage key, so we
      // fail fast here with a descriptive error instead of a runtime crash.
      guard
        let url = URL(string: urlString),
        url.scheme?.isEmpty == false,
        let host = url.host, host.isEmpty == false
      else {
        AppLog.supabase
          .error(
            "SupabaseEnvironment invalid URL: '\(urlString, privacy: .public)' (needs scheme and host)")
        debugConfigurationFailure("SupabaseEnvironment invalid URL: \(urlString)")
        throw ConfigurationError.invalidURL(urlString)
      }

      // Prefer the new publishable key name if present; fall back to legacy anon key.
      let anonResolved = try resolveAnyValue(
        keys: ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"],
        infoDictionary: infoDictionary,
        environment: environment)

      // Check for unresolved placeholder in key
      if anonResolved.value.contains("$(") {
        AppLog.supabase
          .error(
            "Placeholder \(anonResolved.key, privacy: .public): \(anonResolved.value, privacy: .public)")
        throw ConfigurationError.unresolvedPlaceholder(key: anonResolved.key)
      }

      let anonKey = anonResolved.value.trimmingCharacters(in: .whitespacesAndNewlines)

      // Basic validation of the key format
      if anonKey.isEmpty {
        AppLog.supabase.error("\(anonResolved.key, privacy: .public) is empty")
        throw ConfigurationError.missingValue(key: anonResolved.key)
      }

      let hostForLog = host
      let schemeForLog = url.scheme ?? "<nil>"
      AppLog.supabase.info(
        "Resolved SUPABASE_URL source=\(rawURL.source.description, privacy: .public)")
      AppLog.supabase.info(
        "Resolved SUPABASE_URL scheme=\(schemeForLog, privacy: .public) host=\(hostForLog, privacy: .public)")
      AppLog.supabase.info(
        "Resolved \(anonResolved.key, privacy: .public) source=\(anonResolved.source.description, privacy: .public)")
      AppLog.supabase.info(
        "Resolved \(anonResolved.key, privacy: .public) length=\(anonKey.count)")

      AppLog.supabase.info("Supabase environment configuration loaded successfully")
      return SupabaseEnvironment(url: url, anonKey: anonKey)

    } catch {
      AppLog.supabase.error("Failed to load Supabase environment: \(error.localizedDescription, privacy: .public)")
      throw error
    }
  }

  private static func resolveValue(
    key: String,
    infoDictionary: [String: Any]?,
    environment: [String: String]) throws -> ResolvedValue
  {
    if let infoValue = infoDictionary?[key] as? String, infoValue.isEmpty == false {
      guard infoValue.contains("$(") == false else {
        debugConfigurationFailure("SupabaseEnvironment unresolved placeholder for key \(key)")
        throw ConfigurationError.unresolvedPlaceholder(key: key)
      }
      return ResolvedValue(key: key, value: infoValue, source: .infoDictionary)
    }

    if let envValue = environment[key], envValue.isEmpty == false {
      return ResolvedValue(key: key, value: envValue, source: .processEnvironment)
    }

    debugConfigurationFailure("SupabaseEnvironment missing configuration for key \(key)")
    throw ConfigurationError.missingValue(key: key)
  }

  /// Resolves the first present, non-empty value among the provided keys.
  private static func resolveAnyValue(
    keys: [String],
    infoDictionary: [String: Any]?,
    environment: [String: String]) throws -> ResolvedValue
  {
    for key in keys {
      if let infoValue = infoDictionary?[key] as? String, infoValue.isEmpty == false,
         infoValue.contains("$(") == false
      {
        return ResolvedValue(key: key, value: infoValue, source: .infoDictionary)
      }
      if let envValue = environment[key], envValue.isEmpty == false {
        return ResolvedValue(key: key, value: envValue, source: .processEnvironment)
      }
    }
    if let firstKey = keys.first {
      debugConfigurationFailure("SupabaseEnvironment missing configuration for keys \(keys.joined(separator: ", "))")
      throw ConfigurationError.missingValue(key: firstKey)
    }
    debugConfigurationFailure("SupabaseEnvironment missing configuration for provided keys array")
    throw ConfigurationError.missingValue(key: "<unknown>")
  }
}

private func debugConfigurationFailure(_ message: String) {
  #if DEBUG
  let divider = String(repeating: "━", count: 69)
  if TestEnvironment.isRunningTests {
    AppLog.supabase.warning("Skipping Supabase configuration assertion during tests: \(message, privacy: .public)")
    return
  }
  assertionFailure(message)
  AppLog.supabase.error("CONFIGURATION ERROR: \(message, privacy: .public)")
  print(divider)
  print("🚨 SUPABASE CONFIGURATION PROBLEM")
  print(divider)
  print("   \(message)")
  print("")
  print("💡 QUICK FIX:")
  print("   1. Check if RefWatchiOS/Config/Secrets.xcconfig exists")
  print("   2. Verify it contains valid SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY")
  print("   3. Ensure Secrets.xcconfig is included in your Xcode project")
  print("   4. Clean build folder and rebuild")
  print("")
  print("📄 Example Secrets.xcconfig:")
  print("   SUPABASE_URL = https://yourproject.supabase.co")
  print("   SUPABASE_PUBLISHABLE_KEY = your_publishable_key_here")
  print(divider)
  #endif
}
