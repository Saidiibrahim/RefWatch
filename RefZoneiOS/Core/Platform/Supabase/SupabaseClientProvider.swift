//
//  SupabaseClientProvider.swift
//  RefZoneiOS
//
//  Centralized factory for a shared Supabase client instance. The provider
//  hides how configuration is loaded so feature code only thinks about
//  calling services.
//

import CoreFoundation
import Foundation
import OSLog
import Supabase

protocol SupabaseClientProviding {
  func client() throws -> SupabaseClientRepresenting
  func authorizedClient() async throws -> SupabaseClientRepresenting
  func clerkToken() async throws -> String
}

struct SupabaseQueryFilter: Equatable {
  enum Operator: Equatable {
    case equals
    case greaterThan
    case `in`
  }

  enum Value: Equatable {
    case scalar(String)
    case collection([String])
  }

  let column: String
  let op: Operator
  let value: Value

  static func equals(_ column: String, value: String) -> SupabaseQueryFilter {
    SupabaseQueryFilter(column: column, op: .equals, value: .scalar(value))
  }

  static func greaterThan(_ column: String, value: String) -> SupabaseQueryFilter {
    SupabaseQueryFilter(column: column, op: .greaterThan, value: .scalar(value))
  }

  static func `in`(_ column: String, values: [String]) -> SupabaseQueryFilter {
    SupabaseQueryFilter(column: column, op: .in, value: .collection(values))
  }

}

enum SupabaseClientError: Error, Equatable, Sendable {
  case invalidRPCParameters
  case emptyRPCResponse
}

protocol SupabaseClientRepresenting: AnyObject {
  var functionsClient: SupabaseFunctionsClientRepresenting { get }
  func fetchRows<T: Decodable>(
    from table: String,
    select columns: String,
    filters: [SupabaseQueryFilter],
    orderBy column: String?,
    ascending: Bool,
    limit: Int,
    decoder: JSONDecoder
  ) async throws -> [T]
  func callRPC<Params: Encodable, Response: Decodable>(
    _ function: String,
    params: Params,
    encoder: JSONEncoder,
    decoder: JSONDecoder
  ) async throws -> Response
}

protocol SupabaseFunctionsClientRepresenting: AnyObject {
  func setAuth(token: String?)
  func invoke<T: Decodable>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder
  ) async throws -> T
}

extension SupabaseClient: SupabaseClientRepresenting {
  var functionsClient: SupabaseFunctionsClientRepresenting { functions }
  func fetchRows<T: Decodable>(
    from table: String,
    select columns: String,
    filters: [SupabaseQueryFilter],
    orderBy column: String?,
    ascending: Bool,
    limit: Int,
    decoder: JSONDecoder
  ) async throws -> [T] {
    var query = from(table).select(columns)

    for filter in filters {
      switch filter.op {
      case .equals:
        if case let .scalar(value) = filter.value {
          query = query.eq(filter.column, value: value)
        }
      case .greaterThan:
        if case let .scalar(value) = filter.value {
          query = query.gt(filter.column, value: value)
        }
      case .in:
        if case let .collection(values) = filter.value, values.isEmpty == false {
          query = query.in(filter.column, values: values) as! PostgrestFilterBuilder
        }
      }
    }

    if let column {
      // Supabase Swift updated signatures: first params are unlabeled.
      // Using unlabeled column + limit avoids "Extraneous argument label" errors.
        query = query.order(column, ascending: ascending) as! PostgrestFilterBuilder
    }

    if limit > 0 {
        query = query.limit(limit) as! PostgrestFilterBuilder
    }

    let response = try await query.execute()
    let data = response.data
    if data.isEmpty {
      return []
    }
    return try decoder.decode([T].self, from: data)
  }

  func callRPC<Params: Encodable, Response: Decodable>(
    _ function: String,
    params: Params,
    encoder: JSONEncoder,
    decoder: JSONDecoder
  ) async throws -> Response {
    let encodedParams = try encoder.encode(params)
    let jsonObject = try JSONSerialization.jsonObject(with: encodedParams)
    guard let dictionary = jsonObject as? [String: Any] else {
      throw SupabaseClientError.invalidRPCParameters
    }

    let payload = try EncodableDictionary(anyDictionary: dictionary)
      let response = try await database.rpc(
      function,
      params: payload
    ).execute()
    let data = response.data
    guard data.isEmpty == false else {
      throw SupabaseClientError.emptyRPCResponse
    }
    return try decoder.decode(Response.self, from: data)
  }
}

private struct EncodableDictionary: Encodable, Sendable {
  let values: [String: JSONValue]

  init(anyDictionary: [String: Any]) throws {
    var converted: [String: JSONValue] = [:]
    converted.reserveCapacity(anyDictionary.count)
    for (key, value) in anyDictionary {
      converted[key] = try JSONValue(any: value)
    }
    self.values = converted
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (key, value) in values {
      guard let codingKey = DynamicCodingKey(stringValue: key) else {
        throw SupabaseClientError.invalidRPCParameters
      }
      try container.encode(value, forKey: codingKey)
    }
  }
}

private struct DynamicCodingKey: CodingKey, Sendable {
  let stringValue: String
  let intValue: Int? = nil

  init?(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue: Int) {
    return nil
  }
}

private enum JSONValue: Sendable {
  case string(String)
  case bool(Bool)
  case integer(Int64)
  case double(Double)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(any: Any) throws {
    switch any {
    case let string as String:
      self = .string(string)
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        self = .bool(number.boolValue)
      } else if CFNumberIsFloatType(number) {
        self = .double(number.doubleValue)
      } else {
        self = .integer(number.int64Value)
      }
    case let dictionary as [String: Any]:
      var converted: [String: JSONValue] = [:]
      converted.reserveCapacity(dictionary.count)
      for (key, value) in dictionary {
        converted[key] = try JSONValue(any: value)
      }
      self = .object(converted)
    case let array as [Any]:
      self = .array(try array.map { try JSONValue(any: $0) })
    case is NSNull:
      self = .null
    default:
      throw SupabaseClientError.invalidRPCParameters
    }
  }
}

extension JSONValue: Encodable {
  func encode(to encoder: Encoder) throws {
    switch self {
    case let .string(value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case let .bool(value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case let .integer(value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case let .double(value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case let .array(values):
      var container = encoder.unkeyedContainer()
      for value in values {
        try container.encode(value)
      }
    case let .object(values):
      var container = encoder.container(keyedBy: DynamicCodingKey.self)
      for (key, value) in values {
        guard let codingKey = DynamicCodingKey(stringValue: key) else {
          throw SupabaseClientError.invalidRPCParameters
        }
        try container.encode(value, forKey: codingKey)
      }
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }
}

extension FunctionsClient: SupabaseFunctionsClientRepresenting {}

final class SupabaseClientProvider: SupabaseClientProviding {
  static let shared = SupabaseClientProvider()

  typealias ClientFactory = (SupabaseEnvironment, SupabaseTokenProviding) throws -> SupabaseClientRepresenting

  private let environmentLoader: () throws -> SupabaseEnvironment
  private let tokenProvider: SupabaseTokenProviding
  private let clientFactory: ClientFactory
  private var cachedClient: SupabaseClientRepresenting?
  private var cachedEnvironment: SupabaseEnvironment?
  private let lock = NSLock()

  init(
    environmentLoader: @escaping () throws -> SupabaseEnvironment = { try SupabaseEnvironment.load() },
    tokenProvider: SupabaseTokenProviding = SupabaseTokenProvider(),
    clientFactory: @escaping ClientFactory = { environment, tokenProvider in
      let instance = SupabaseClient(
        supabaseURL: environment.url,
        supabaseKey: environment.anonKey,
        options: SupabaseClientOptions(
          auth: SupabaseClientOptions.AuthOptions(
            accessToken: {
              try await tokenProvider.currentToken()
            }
          )
        )
      )
      return instance
    }
  ) {
    self.environmentLoader = environmentLoader
    self.tokenProvider = tokenProvider
    self.clientFactory = clientFactory
  }

  func client() throws -> SupabaseClientRepresenting {
    lock.lock()
    defer { lock.unlock() }

    if let cachedClient {
      return cachedClient
    }

    let environment = try environmentLoader()
    // Validate that the resolved Supabase URL has a non-empty host before
    // handing it to the SDK. The SDK computes a default storage key using
    // `supabaseURL.host!` during initialization; if `host` is nil (e.g., due
    // to malformed input or stray whitespace), it would crash with a fatal
    // unwrap. Surfacing a descriptive configuration error here makes Settings
    // diagnostics much clearer and avoids a hard crash.
    guard let host = environment.url.host, host.isEmpty == false else {
      throw SupabaseEnvironment.ConfigurationError.invalidURL(environment.url.absoluteString)
    }
    let tokenProvider = self.tokenProvider
    let instance = try clientFactory(environment, tokenProvider)
    // Diagnostics: log resolved host and anon key length only (not the key
    // itself). Helps quickly spot misconfiguration in local/dev builds.
    let hostForLog = environment.url.host ?? "<nil>"
    AppLog.supabase.info("Creating Supabase client host=\(hostForLog, privacy: .public) anonLen=\(environment.anonKey.count)")
    cachedClient = instance
    cachedEnvironment = environment
    return instance
  }

  func authorizedClient() async throws -> SupabaseClientRepresenting {
    let client = try client()
    if let environment = cachedEnvironment {
      client.functionsClient.setAuth(token: environment.anonKey)
    }
    return client
  }

  func clerkToken() async throws -> String {
    do {
      let token = try await tokenProvider.currentToken()
      return token
    } catch {
      AppLog.supabase.error("Failed to fetch Clerk token: \(error.localizedDescription, privacy: .public)")
      throw error
    }
  }

  func reset() {
    lock.lock()
    cachedClient = nil
    cachedEnvironment = nil
    lock.unlock()
  }
}
