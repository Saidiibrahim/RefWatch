//
//  SupabaseClientProvider.swift
//  RefWatchiOS
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
  func refreshFunctionAuth() async
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

struct SupabaseFetchRequest {
  let table: String
  let columns: String
  let filters: [SupabaseQueryFilter]
  let orderBy: String?
  let ascending: Bool
  let limit: Int
  let decoder: JSONDecoder
}

enum SupabaseClientError: Error, Equatable, Sendable {
  case invalidRPCParameters
  case emptyRPCResponse
}

enum SupabaseTestClientError: Error, Equatable, Sendable {
  case unavailable
}

protocol SupabaseClientRepresenting: AnyObject, Sendable {
  var functionsClient: SupabaseFunctionsClientRepresenting { get }
  func fetchRows<T: Decodable>(_ request: SupabaseFetchRequest) async throws -> [T]
  func callRPC<Params: Encodable, Response: Decodable>(
    _ function: String,
    params: Params,
    encoder: JSONEncoder,
    decoder: JSONDecoder) async throws -> Response
  func upsertRows<Payload: Encodable, Response: Decodable>(
    into table: String,
    payload: Payload,
    onConflict: String,
    decoder: JSONDecoder) async throws -> Response
}

protocol SupabaseFunctionsClientRepresenting: AnyObject, Sendable {
  func setAuth(token: String?)
  func invoke<Response>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decode: (Data, HTTPURLResponse) throws -> Response) async throws -> Response
  func invoke<T: Decodable>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder) async throws -> T
}

private final class TestSupabaseFunctionsClient: SupabaseFunctionsClientRepresenting, @unchecked Sendable {
  func setAuth(token: String?) {}

  func invoke<Response>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decode: (Data, HTTPURLResponse) throws -> Response) async throws -> Response
  {
    throw SupabaseTestClientError.unavailable
  }

  func invoke<T: Decodable>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder) async throws -> T
  {
    throw SupabaseTestClientError.unavailable
  }
}

private final class TestSupabaseClient: SupabaseClientRepresenting, @unchecked Sendable {
  let functionsClient: SupabaseFunctionsClientRepresenting = TestSupabaseFunctionsClient()

  func fetchRows<T: Decodable>(_ request: SupabaseFetchRequest) async throws -> [T] {
    []
  }

  func callRPC<Response: Decodable>(
    _ function: String,
    params: some Encodable,
    encoder: JSONEncoder,
    decoder: JSONDecoder) async throws -> Response
  {
    throw SupabaseTestClientError.unavailable
  }

  func upsertRows<Response: Decodable>(
    into table: String,
    payload: some Encodable,
    onConflict: String,
    decoder: JSONDecoder) async throws -> Response
  {
    throw SupabaseTestClientError.unavailable
  }
}

// The SDK types are now Sendable by default in modern Supabase SDK versions

extension SupabaseClient: SupabaseClientRepresenting {
  var functionsClient: SupabaseFunctionsClientRepresenting { functions }
  func fetchRows<T: Decodable>(_ request: SupabaseFetchRequest) async throws -> [T] {
    var filterQuery = from(request.table).select(request.columns)

    for filter in request.filters {
      switch filter.op {
      case .equals:
        if case let .scalar(value) = filter.value {
          filterQuery = filterQuery.eq(filter.column, value: value)
        }
      case .greaterThan:
        if case let .scalar(value) = filter.value {
          filterQuery = filterQuery.gt(filter.column, value: value)
        }
      case .in:
        if case let .collection(values) = filter.value, values.isEmpty == false {
          filterQuery = filterQuery.in(filter.column, values: values)
        }
      }
    }

    var query: PostgrestTransformBuilder = filterQuery

    if let column = request.orderBy {
      // Supabase Swift updated signatures: first params are unlabeled.
      // Using unlabeled column + limit avoids "Extraneous argument label" errors.
      query = query.order(column, ascending: request.ascending)
    }

    if request.limit > 0 {
      query = query.limit(request.limit)
    }

    let response = try await query.execute()
    let data = response.data
    if data.isEmpty {
      return []
    }
    return try request.decoder.decode([T].self, from: data)
  }

  func callRPC<Response: Decodable>(
    _ function: String,
    params: some Encodable,
    encoder: JSONEncoder,
    decoder: JSONDecoder) async throws -> Response
  {
    let encodedParams = try encoder.encode(params)
    let jsonObject = try JSONSerialization.jsonObject(with: encodedParams)
    guard let dictionary = jsonObject as? [String: Any] else {
      throw SupabaseClientError.invalidRPCParameters
    }

    let payload = try EncodableDictionary(anyDictionary: dictionary)
    let response = try await self.rpc(
      function,
      params: payload).execute()
    let data = response.data
    guard data.isEmpty == false else {
      throw SupabaseClientError.emptyRPCResponse
    }
    return try decoder.decode(Response.self, from: data)
  }

  func upsertRows<Response>(
    into table: String,
    payload: some Encodable,
    onConflict: String,
    decoder: JSONDecoder) async throws -> Response where Response: Decodable
  {
    let response = try await from(table)
      .upsert(payload, onConflict: onConflict, returning: .representation)
      .execute()
    return try decoder.decode(Response.self, from: response.data)
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

  nonisolated func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (key, value) in self.values {
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
    nil
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
      self = try .array(array.map { try JSONValue(any: $0) })
    case is NSNull:
      self = .null
    default:
      throw SupabaseClientError.invalidRPCParameters
    }
  }
}

extension JSONValue: Encodable {
  nonisolated func encode(to encoder: Encoder) throws {
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
  private static let isRunningTests = TestEnvironment.isRunningTests

  typealias ClientFactory = (SupabaseEnvironment) throws -> SupabaseClientRepresenting

  private let environmentLoader: () throws -> SupabaseEnvironment
  private let clientFactory: ClientFactory
  private var cachedClient: SupabaseClientRepresenting?
  private var cachedEnvironment: SupabaseEnvironment?
  private let lock = NSLock()

  init(
    environmentLoader: @escaping () throws -> SupabaseEnvironment = { try SupabaseEnvironment.load() },
    clientFactory: @escaping ClientFactory = { environment in
      let instance = SupabaseClient(
        supabaseURL: environment.url,
        supabaseKey: environment.anonKey,
        options: SupabaseClientOptions())
      return instance
    })
  {
    self.environmentLoader = environmentLoader
    self.clientFactory = clientFactory
  }

  func client() throws -> SupabaseClientRepresenting {
    self.lock.lock()
    defer { lock.unlock() }

    if let cachedClient {
      return cachedClient
    }

    AppLog.supabase.info("Creating new Supabase client...")

    do {
      let environment = try environmentLoader()

      // Validate that the resolved Supabase URL has a non-empty host before
      // handing it to the SDK. The SDK computes a default storage key using
      // `supabaseURL.host!` during initialization; if `host` is nil (e.g., due
      // to malformed input or stray whitespace), it would crash with a fatal
      // unwrap. Surfacing a descriptive configuration error here makes Settings
      // diagnostics much clearer and avoids a hard crash.
      guard let host = environment.url.host, host.isEmpty == false else {
        AppLog.supabase
          .error(
            "Supabase client creation failed: invalid URL host - \(environment.url.absoluteString, privacy: .public)")
        throw SupabaseEnvironment.ConfigurationError.invalidURL(environment.url.absoluteString)
      }

      let instance = try clientFactory(environment)

      // Diagnostics: log resolved host and anon key length only (not the key
      // itself). Helps quickly spot misconfiguration in local/dev builds.
      let hostForLog = environment.url.host ?? "<nil>"
      AppLog.supabase
        .info(
          "Supabase client created host=\(hostForLog, privacy: .public) anonLen=\(environment.anonKey.count)")

      cachedClient = instance
      self.cachedEnvironment = environment
      return instance

    } catch {
      if Self.isRunningTests {
        let testClient = TestSupabaseClient()
        AppLog.supabase
          .warning(
            "Supabase config missing during tests; using test client. \(error.localizedDescription, privacy: .public)")
        cachedClient = testClient
        return testClient
      }
      AppLog.supabase.error("Failed to create Supabase client: \(error.localizedDescription, privacy: .public)")
      throw error
    }
  }

  func authorizedClient() async throws -> SupabaseClientRepresenting {
    do {
      let client = try client()
      await refreshFunctionAuth()
      AppLog.supabase.info("Authorized Supabase client ready")
      return client
    } catch {
      AppLog.supabase.error("Failed to get authorized Supabase client: \(error.localizedDescription, privacy: .public)")
      throw error
    }
  }

  func refreshFunctionAuth() async {
    guard let client = cachedClient else { return }

    if let supabaseClient = client as? SupabaseClient {
      // Fetch the current session asynchronously to ensure we have the latest token
      // CRITICAL: Do not fall back to anon key for authenticated edge functions.
      // The caller must handle session errors explicitly to maintain security.
      do {
        let session = try await supabaseClient.auth.session
        let token = session.accessToken
        client.functionsClient.setAuth(token: token)
        let tokenPrefix = String(token.prefix(20))
        AppLog.supabase.debug("Functions auth updated with session token prefix=\(tokenPrefix, privacy: .public)")
      } catch {
        // Clear any stale token to prevent using outdated credentials
        client.functionsClient.setAuth(token: nil)
        AppLog.supabase
          .error("Functions auth failed - no valid session: \(error.localizedDescription, privacy: .public)")
        // Note: Caller should handle this by ensuring user is signed in before invoking functions
      }
    } else {
      // For non-SupabaseClient implementations, clear auth token
      client.functionsClient.setAuth(token: nil)
    }
  }

  func reset() {
    self.lock.lock()
    self.cachedClient = nil
    self.cachedEnvironment = nil
    self.lock.unlock()
  }
}
