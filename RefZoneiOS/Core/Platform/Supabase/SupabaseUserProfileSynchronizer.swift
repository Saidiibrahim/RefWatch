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
    let appMetadata = Self.metadataJSON(from: user.appMetadata)
    let userMetadata = Self.metadataJSON(from: user.userMetadata)

    return SupabaseUserProfilePayload(
      id: user.id,
      email: user.email,
      displayName: Self.displayName(from: user),
      avatarURL: Self.avatarURL(from: userMetadata),
      emailVerified: user.emailConfirmedAt != nil,
      lastSignInAt: user.lastSignInAt,
      rawAppMetadata: AnyEncodable(appMetadata),
      rawUserMetadata: AnyEncodable(userMetadata),
      createdAt: user.createdAt,
      updatedAt: user.updatedAt ?? now()
    )
  }

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func displayName(from user: User) -> String? {
    let metadata = metadataJSON(from: user.userMetadata)
    if let name = string(for: "full_name", in: metadata) { return name }
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
    if let dictionary = value as? [String: Any] {
      return dictionary
    }

    if let value,
       let data = try? JSONEncoder().encode(AnyEncodable(value)),
       let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return object
    }

    return [:]
  }
}

struct SupabaseUserProfilePayload: Encodable {
  let id: UUID
  let email: String?
  let displayName: String?
  let avatarURL: String?
  let emailVerified: Bool
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
    switch value {
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
