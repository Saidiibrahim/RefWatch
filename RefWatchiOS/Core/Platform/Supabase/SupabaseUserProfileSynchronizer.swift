//
//  SupabaseUserProfileSynchronizer.swift
//  RefWatchiOS
//
//  Ensures Supabase Auth sessions have a matching row in public.users so
//  downstream repositories can rely on the FK owner references.
//

import CoreFoundation
import Foundation
import Supabase

protocol SupabaseUserProfileSynchronizing {
  func syncIfNeeded(session: Session?) async throws
}

struct SupabaseUserProfileSynchronizer: SupabaseUserProfileSynchronizing {
  private let clientProvider: SupabaseClientProviding
  private let now: () -> Date

  init(
    clientProvider: SupabaseClientProviding,
    now: @escaping () -> Date = { Date() })
  {
    self.clientProvider = clientProvider
    self.now = now
  }

  func syncIfNeeded(session: Session?) async throws {
    guard let session else { return }

    let client = try clientProvider.client()
    let payload = makePayload(from: session)

    _ = try await client.upsertRows(
      into: "users",
      payload: [payload],
      onConflict: "id",
      decoder: Self.makeDecoder()) as [SupabaseUserProfileRow]
  }
}

extension SupabaseUserProfileSynchronizer {
  private func makePayload(from session: Session) -> SupabaseUserProfilePayload {
    let user = session.user
    let appMetadata = Self.normalizeAppMetadata(Self.metadataJSON(from: user.appMetadata))
    let userMetadata = Self.normalizeUserMetadata(Self.metadataJSON(from: user.userMetadata))

    let isSSOUser = Self.boolProperty(named: "isSSOUser", in: user)
      ?? Self.boolProperty(named: "isSsoUser", in: user)
      ?? Self.bool(for: "is_sso_user", in: appMetadata)
      ?? false

    let isAnonymous = Self.boolProperty(named: "isAnonymous", in: user)
      ?? Self.bool(for: "is_anonymous", in: userMetadata)
      ?? false

    return SupabaseUserProfilePayload(
      id: user.id,
      email: user.email,
      displayName: Self.displayName(from: user),
      avatarURL: Self.avatarURL(from: userMetadata),
      emailVerified: user.emailConfirmedAt != nil,
      emailConfirmedAt: user.emailConfirmedAt,
      isSSOUser: isSSOUser,
      isAnonymous: isAnonymous,
      lastSignInAt: user.lastSignInAt,
      rawAppMetadata: AnyEncodable(appMetadata),
      rawUserMetadata: AnyEncodable(userMetadata),
      createdAt: user.createdAt,
      updatedAt: user.updatedAt)
  }

  fileprivate static func makeDecoder() -> JSONDecoder {
    SupabaseJSONDecoderFactory.makeDecoder()
  }

  fileprivate static func displayName(from user: User) -> String? {
    let metadata = self.metadataJSON(from: user.userMetadata)
    if let name = string(for: "full_name", in: metadata) { return name }
    if let given = string(for: "name", in: metadata) { return given }
    if let display = string(for: "display_name", in: metadata) { return display }
    if let username = string(for: "username", in: metadata) { return username }
    if let email = user.email, email.isEmpty == false { return email }
    return nil
  }

  fileprivate static func avatarURL(from metadata: [String: Any]) -> String? {
    if let direct = string(for: "avatar_url", in: metadata) { return direct }
    if let picture = string(for: "picture", in: metadata) { return picture }
    if let image = string(for: "image", in: metadata) { return image }
    return nil
  }

  fileprivate static func string(for key: String, in metadata: [String: Any]?) -> String? {
    guard let value = metadata?[key] else { return nil }
    if let stringValue = value as? String {
      let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }

  fileprivate static func metadataJSON(from value: Any?) -> [String: Any] {
    let resolved = self.resolveJSONValue(value)
    return resolved as? [String: Any] ?? [:]
  }

  fileprivate static func unwrap(_ dictionary: [String: AnyJSON]) -> [String: Any] {
    dictionary.reduce(into: [String: Any]()) { result, element in
      result[element.key] = self.unwrap(element.value)
    }
  }

  fileprivate static func unwrap(_ value: AnyJSON) -> Any {
    switch value {
    case .null:
      NSNull()
    case let .bool(bool):
      bool
    case let .integer(int):
      int
    case let .double(double):
      double
    case let .string(string):
      string
    case let .object(dictionary):
      self.unwrap(dictionary)
    case let .array(array):
      array.map { self.unwrap($0) }
    }
  }

  fileprivate static func resolveJSONValue(_ value: Any?) -> Any {
    guard let value else { return NSNull() }

    if let optionalResolved = resolveOptional(value) {
      return optionalResolved
    }

    if let anyCodableResolved = resolveAnyCodable(value) {
      return self.resolveJSONValue(anyCodableResolved)
    }

    switch value {
    case let json as AnyJSON:
      return self.unwrap(json)
    case let dictionary as [String: AnyJSON]:
      return self.unwrap(dictionary)
    case let array as [AnyJSON]:
      return array.map { self.unwrap($0) }
    case let dictionary as [String: Any]:
      return dictionary.reduce(into: [String: Any]()) { result, element in
        let resolvedValue = self.resolveJSONValue(element.value)
        if !(resolvedValue is NSNull) {
          result[element.key] = resolvedValue
        }
      }
    case let dictionary as NSDictionary:
      var normalized: [String: Any] = [:]
      for (key, rawValue) in dictionary {
        guard let key = key as? String else { continue }
        let resolvedValue = self.resolveJSONValue(rawValue)
        if !(resolvedValue is NSNull) {
          normalized[key] = resolvedValue
        }
      }
      return normalized
    case _ where canResolveDictionaryViaMirror(value):
      return resolveDictionaryViaMirror(value)
    case let array as [Any]:
      return array.map { element -> Any in
        let resolved = self.resolveJSONValue(element)
        return resolved is NSNull ? NSNull() : resolved
      }
    case let array as NSArray:
      return array.map { element -> Any in
        let resolved = self.resolveJSONValue(element)
        return resolved is NSNull ? NSNull() : resolved
      }
    case _ where canResolveCollectionViaMirror(value):
      return resolveCollectionViaMirror(value)
    default:
      return value
    }
  }

  fileprivate static func resolveOptional(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return nil }
    guard let child = mirror.children.first else { return NSNull() }
    return self.resolveJSONValue(child.value)
  }

  fileprivate static func resolveAnyCodable(_ value: Any) -> Any? {
    let typeName = String(describing: type(of: value))
    guard typeName.contains("AnyCodable") else { return nil }

    let mirror = Mirror(reflecting: value)
    if let child = mirror.children.first(where: { $0.label == "value" }) {
      return child.value
    }

    return nil
  }

  fileprivate static func normalizeAppMetadata(_ metadata: [String: Any]) -> [String: Any] {
    var normalized = metadata
    normalized["providers"] = self.normalizeProviders(metadata["providers"])
    return normalized
  }

  fileprivate static func normalizeUserMetadata(_ metadata: [String: Any]) -> [String: Any] {
    var normalized = metadata
    if let claims = metadata["custom_claims"] {
      normalized["custom_claims"] = self.normalizeCustomClaims(claims)
    }
    if let verified = parseBoolean(metadata["email_verified"]) {
      normalized["email_verified"] = verified
    }
    if let verified = parseBoolean(metadata["phone_verified"]) {
      normalized["phone_verified"] = verified
    }
    return normalized
  }

  fileprivate static func normalizeProviders(_ value: Any?) -> [String] {
    guard let value else { return [] }

    let resolved = self.resolveJSONValue(value)

    if resolved is NSNull {
      return []
    }

    if let array = resolved as? [Any] {
      return self.normalizeProviderArray(array)
    }

    if let string = resolved as? String {
      if let data = string.data(using: .utf8),
         let parsed = try? JSONSerialization.jsonObject(with: data) as? [Any]
      {
        return self.normalizeProviders(parsed)
      }

      let segments = string
        .split(separator: ",")
        .map { String($0) }

      return self.normalizeProviderArray(segments.map { $0 as Any })
    }

    return []
  }

  fileprivate static func normalizeProviderArray(_ elements: [Any]) -> [String] {
    var seen = Set<String>()
    var normalized: [String] = []

    for element in elements {
      let rawString: String? = switch self.resolveJSONValue(element) {
      case let string as String:
        string
      case let bool as Bool:
        bool ? "true" : "false"
      case let int as Int:
        String(int)
      case let double as Double:
        String(double)
      case let number as NSNumber:
        number.stringValue
      default:
        nil
      }

      guard let raw = rawString?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else {
        continue
      }

      let lowered = raw.lowercased()
      if lowered == "null" || seen.contains(lowered) {
        continue
      }

      seen.insert(lowered)
      normalized.append(lowered)
    }

    return normalized
  }

  fileprivate static func normalizeCustomClaims(_ value: Any) -> [String: Any] {
    let resolved = self.resolveJSONValue(value)
    if let dictionary = resolved as? [String: Any] {
      return dictionary
    }

    if let string = resolved as? String,
       let data = string.data(using: .utf8),
       let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      return dictionary
    }

    return [:]
  }

  fileprivate static func parseBoolean(_ value: Any?) -> Bool? {
    let resolved = self.resolveJSONValue(value)

    switch resolved {
    case let bool as Bool:
      return bool
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        return number.boolValue
      }
      return number.intValue != 0
    case let string as String:
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      switch trimmed {
      case "true", "t", "1", "yes": return true
      case "false", "f", "0", "no": return false
      default: return nil
      }
    default:
      return nil
    }
  }

  fileprivate static func bool(for key: String, in metadata: [String: Any]) -> Bool? {
    guard let value = metadata[key] else { return nil }
    return self.parseBoolean(value)
  }

  fileprivate static func boolProperty(named key: String, in user: User) -> Bool? {
    guard let value = Mirror(reflecting: user).children.first(where: { $0.label == key })?.value else {
      return nil
    }

    if let bool = value as? Bool {
      return bool
    }

    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
      return mirror.children.first?.value as? Bool
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return nil
  }
}

extension SupabaseUserProfileSynchronizer {
  fileprivate static func canResolveDictionaryViaMirror(_ value: Any) -> Bool {
    Mirror(reflecting: value).displayStyle == .dictionary
  }

  fileprivate static func resolveDictionaryViaMirror(_ value: Any) -> [String: Any] {
    let mirror = Mirror(reflecting: value)
    var result: [String: Any] = [:]

    for child in mirror.children {
      let pairMirror = Mirror(reflecting: child.value)
      guard pairMirror.displayStyle == .tuple else { continue }

      var key: String?
      var value: Any?

      for tupleChild in pairMirror.children {
        switch tupleChild.label {
        case "key":
          key = tupleChild.value as? String
        case "value":
          value = tupleChild.value
        default:
          break
        }
      }

      guard let key, let rawValue = value else { continue }
      let resolvedValue = self.resolveJSONValue(rawValue)
      if !(resolvedValue is NSNull) {
        result[key] = resolvedValue
      }
    }

    return result
  }

  fileprivate static func canResolveCollectionViaMirror(_ value: Any) -> Bool {
    Mirror(reflecting: value).displayStyle == .collection
  }

  fileprivate static func resolveCollectionViaMirror(_ value: Any) -> [Any] {
    let mirror = Mirror(reflecting: value)
    return mirror.children.map { element -> Any in
      let resolved = self.resolveJSONValue(element.value)
      return resolved is NSNull ? NSNull() : resolved
    }
  }
}

struct SupabaseUserProfilePayload: Encodable {
  let id: UUID
  let email: String?
  let displayName: String?
  let avatarURL: String?
  let emailVerified: Bool
  let emailConfirmedAt: Date?
  let isSSOUser: Bool
  let isAnonymous: Bool
  let lastSignInAt: Date?
  let rawAppMetadata: AnyEncodable
  let rawUserMetadata: AnyEncodable
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case email
    case displayName = "display_name"
    case avatarURL = "avatar_url"
    case emailVerified = "email_verified"
    case emailConfirmedAt = "email_confirmed_at"
    case isSSOUser = "is_sso_user"
    case isAnonymous = "is_anonymous"
    case lastSignInAt = "last_sign_in_at"
    case rawAppMetadata = "raw_app_metadata"
    case rawUserMetadata = "raw_user_metadata"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

struct SupabaseUserProfileRow: Decodable {
  let id: UUID
}

struct AnyEncodable: Encodable {
  private let value: Any

  init(_ value: Any) {
    self.value = value
  }

  func encode(to encoder: Encoder) throws {
    let resolved = SupabaseUserProfileSynchronizer.resolveJSONValue(self.value)

    if resolved is NSNull {
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    } else if let bool = resolved as? Bool {
      var container = encoder.singleValueContainer()
      try container.encode(bool)
    } else if let number = resolved as? NSNumber {
      var container = encoder.singleValueContainer()
      if CFNumberIsFloatType(number) {
        try container.encode(number.doubleValue)
      } else {
        try container.encode(number.int64Value)
      }
    } else if let string = resolved as? String {
      var container = encoder.singleValueContainer()
      try container.encode(string)
    } else if let date = resolved as? Date {
      var container = encoder.singleValueContainer()
      try container.encode(date)
    } else if let url = resolved as? URL {
      var container = encoder.singleValueContainer()
      try container.encode(url.absoluteString)
    } else if let array = resolved as? [Any] {
      var container = encoder.unkeyedContainer()
      for element in array {
        try container.encode(AnyEncodable(element))
      }
    } else if let dictionary = resolved as? [String: Any] {
      var container = encoder.container(keyedBy: DynamicCodingKey.self)
      for (key, value) in dictionary {
        guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
        try container.encode(AnyEncodable(value), forKey: codingKey)
      }
    } else {
      var container = encoder.singleValueContainer()
      try container.encode("\(self.value)")
    }
  }
}

private struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
}
