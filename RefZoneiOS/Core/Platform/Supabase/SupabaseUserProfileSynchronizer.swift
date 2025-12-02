//
//  SupabaseUserProfileSynchronizer.swift
//  RefZoneiOS
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
    now: @escaping () -> Date = { Date() }
  ) {
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
      decoder: Self.makeDecoder()
    ) as [SupabaseUserProfileRow]
  }
}

private extension SupabaseUserProfileSynchronizer {
  func makePayload(from session: Session) -> SupabaseUserProfilePayload {
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
      updatedAt: user.updatedAt
    )
  }

  static func makeDecoder() -> JSONDecoder {
    SupabaseJSONDecoderFactory.makeDecoder()
  }

  static func displayName(from user: User) -> String? {
    let metadata = metadataJSON(from: user.userMetadata)
    if let name = string(for: "full_name", in: metadata) { return name }
    if let given = string(for: "name", in: metadata) { return given }
    if let display = string(for: "display_name", in: metadata) { return display }
    if let username = string(for: "username", in: metadata) { return username }
    if let email = user.email, email.isEmpty == false { return email }
    return nil
  }

  static func avatarURL(from metadata: [String: Any]) -> String? {
    if let direct = string(for: "avatar_url", in: metadata) { return direct }
    if let picture = string(for: "picture", in: metadata) { return picture }
    if let image = string(for: "image", in: metadata) { return image }
    return nil
  }

  static func string(for key: String, in metadata: [String: Any]?) -> String? {
    guard let value = metadata?[key] else { return nil }
    if let stringValue = value as? String {
      let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }

  static func metadataJSON(from value: Any?) -> [String: Any] {
    let resolved = resolveJSONValue(value)
    return resolved as? [String: Any] ?? [:]
  }

  static func unwrap(_ dictionary: [String: AnyJSON]) -> [String: Any] {
    dictionary.reduce(into: [String: Any]()) { result, element in
      result[element.key] = unwrap(element.value)
    }
  }

  static func unwrap(_ value: AnyJSON) -> Any {
    switch value {
    case .null:
      return NSNull()
    case let .bool(bool):
      return bool
    case let .integer(int):
      return int
    case let .double(double):
      return double
    case let .string(string):
      return string
    case let .object(dictionary):
      return unwrap(dictionary)
    case let .array(array):
      return array.map { unwrap($0) }
    }
  }

  static func resolveJSONValue(_ value: Any?) -> Any {
    guard let value else { return NSNull() }

    if let optionalResolved = resolveOptional(value) {
      return optionalResolved
    }

    if let anyCodableResolved = resolveAnyCodable(value) {
      return resolveJSONValue(anyCodableResolved)
    }

    switch value {
    case let json as AnyJSON:
      return unwrap(json)
    case let dictionary as [String: AnyJSON]:
      return unwrap(dictionary)
    case let array as [AnyJSON]:
      return array.map { unwrap($0) }
    case let dictionary as [String: Any]:
      return dictionary.reduce(into: [String: Any]()) { result, element in
        let resolvedValue = resolveJSONValue(element.value)
        if !(resolvedValue is NSNull) {
          result[element.key] = resolvedValue
        }
      }
    case let dictionary as NSDictionary:
      var normalized: [String: Any] = [:]
      for (key, rawValue) in dictionary {
        guard let key = key as? String else { continue }
        let resolvedValue = resolveJSONValue(rawValue)
        if !(resolvedValue is NSNull) {
          normalized[key] = resolvedValue
        }
      }
      return normalized
    case _ where canResolveDictionaryViaMirror(value):
      return resolveDictionaryViaMirror(value)
    case let array as [Any]:
      return array.map { element -> Any in
        let resolved = resolveJSONValue(element)
        return resolved is NSNull ? NSNull() : resolved
      }
    case let array as NSArray:
      return array.map { element -> Any in
        let resolved = resolveJSONValue(element)
        return resolved is NSNull ? NSNull() : resolved
      }
    case _ where canResolveCollectionViaMirror(value):
      return resolveCollectionViaMirror(value)
    default:
      return value
    }
  }

  static func resolveOptional(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return nil }
    guard let child = mirror.children.first else { return NSNull() }
    return resolveJSONValue(child.value)
  }

  static func resolveAnyCodable(_ value: Any) -> Any? {
    let typeName = String(describing: type(of: value))
    guard typeName.contains("AnyCodable") else { return nil }

    let mirror = Mirror(reflecting: value)
    if let child = mirror.children.first(where: { $0.label == "value" }) {
      return child.value
    }

    return nil
  }

  static func normalizeAppMetadata(_ metadata: [String: Any]) -> [String: Any] {
    var normalized = metadata
    normalized["providers"] = normalizeProviders(metadata["providers"])
    return normalized
  }

  static func normalizeUserMetadata(_ metadata: [String: Any]) -> [String: Any] {
    var normalized = metadata
    if let claims = metadata["custom_claims"] {
      normalized["custom_claims"] = normalizeCustomClaims(claims)
    }
    if let verified = parseBoolean(metadata["email_verified"]) {
      normalized["email_verified"] = verified
    }
    if let verified = parseBoolean(metadata["phone_verified"]) {
      normalized["phone_verified"] = verified
    }
    return normalized
  }

  static func normalizeProviders(_ value: Any?) -> [String] {
    guard let value else { return [] }

    let resolved = resolveJSONValue(value)

    if resolved is NSNull {
      return []
    }

    if let array = resolved as? [Any] {
      return normalizeProviderArray(array)
    }

    if let string = resolved as? String {
      if let data = string.data(using: .utf8),
         let parsed = try? JSONSerialization.jsonObject(with: data) as? [Any] {
        return normalizeProviders(parsed)
      }

      let segments = string
        .split(separator: ",")
        .map { String($0) }

      return normalizeProviderArray(segments.map { $0 as Any })
    }

    return []
  }

  static func normalizeProviderArray(_ elements: [Any]) -> [String] {
    var seen = Set<String>()
    var normalized: [String] = []

    for element in elements {
      let rawString: String?

      switch resolveJSONValue(element) {
      case let string as String:
        rawString = string
      case let bool as Bool:
        rawString = bool ? "true" : "false"
      case let int as Int:
        rawString = String(int)
      case let double as Double:
        rawString = String(double)
      case let number as NSNumber:
        rawString = number.stringValue
      default:
        rawString = nil
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

  static func normalizeCustomClaims(_ value: Any) -> [String: Any] {
    let resolved = resolveJSONValue(value)
    if let dictionary = resolved as? [String: Any] {
      return dictionary
    }

    if let string = resolved as? String,
       let data = string.data(using: .utf8),
       let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return dictionary
    }

    return [:]
  }

  static func parseBoolean(_ value: Any?) -> Bool? {
    let resolved = resolveJSONValue(value)

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

  static func bool(for key: String, in metadata: [String: Any]) -> Bool? {
    guard let value = metadata[key] else { return nil }
    return parseBoolean(value)
  }

  static func boolProperty(named key: String, in user: User) -> Bool? {
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

private extension SupabaseUserProfileSynchronizer {
  static func canResolveDictionaryViaMirror(_ value: Any) -> Bool {
    Mirror(reflecting: value).displayStyle == .dictionary
  }

  static func resolveDictionaryViaMirror(_ value: Any) -> [String: Any] {
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
      let resolvedValue = resolveJSONValue(rawValue)
      if !(resolvedValue is NSNull) {
        result[key] = resolvedValue
      }
    }

    return result
  }

  static func canResolveCollectionViaMirror(_ value: Any) -> Bool {
    Mirror(reflecting: value).displayStyle == .collection
  }

  static func resolveCollectionViaMirror(_ value: Any) -> [Any] {
    let mirror = Mirror(reflecting: value)
    return mirror.children.map { element -> Any in
      let resolved = resolveJSONValue(element.value)
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
    let resolved = SupabaseUserProfileSynchronizer.resolveJSONValue(value)

    switch resolved {
    case is NSNull:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    case let bool as Bool:
      var container = encoder.singleValueContainer()
      try container.encode(bool)
    case let int as Int:
      var container = encoder.singleValueContainer()
      try container.encode(int)
    case let int8 as Int8:
      var container = encoder.singleValueContainer()
      try container.encode(int8)
    case let int16 as Int16:
      var container = encoder.singleValueContainer()
      try container.encode(int16)
    case let int32 as Int32:
      var container = encoder.singleValueContainer()
      try container.encode(int32)
    case let int64 as Int64:
      var container = encoder.singleValueContainer()
      try container.encode(int64)
    case let uint as UInt:
      var container = encoder.singleValueContainer()
      try container.encode(uint)
    case let uint8 as UInt8:
      var container = encoder.singleValueContainer()
      try container.encode(uint8)
    case let uint16 as UInt16:
      var container = encoder.singleValueContainer()
      try container.encode(uint16)
    case let uint32 as UInt32:
      var container = encoder.singleValueContainer()
      try container.encode(uint32)
    case let uint64 as UInt64:
      var container = encoder.singleValueContainer()
      try container.encode(uint64)
    case let double as Double:
      var container = encoder.singleValueContainer()
      try container.encode(double)
    case let float as Float:
      var container = encoder.singleValueContainer()
      try container.encode(float)
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        var container = encoder.singleValueContainer()
        try container.encode(number.boolValue)
      } else {
        var container = encoder.singleValueContainer()
        try container.encode(number.doubleValue)
      }
    case let string as String:
      var container = encoder.singleValueContainer()
      try container.encode(string)
    case let date as Date:
      var container = encoder.singleValueContainer()
      try container.encode(date)
    case let url as URL:
      var container = encoder.singleValueContainer()
      try container.encode(url.absoluteString)
    case let array as [Any]:
      var container = encoder.unkeyedContainer()
      for element in array {
        try container.encode(AnyEncodable(element))
      }
    case let dictionary as [String: Any]:
      var container = encoder.container(keyedBy: DynamicCodingKey.self)
      for (key, value) in dictionary {
        guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
        try container.encode(AnyEncodable(value), forKey: codingKey)
      }
    default:
      var container = encoder.singleValueContainer()
      try container.encode("\(value)")
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
