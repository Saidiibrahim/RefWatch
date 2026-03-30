//
//  OpenAIMatchSheetImportService.swift
//  RefWatchiOS
//
//  Calls the authenticated Supabase edge parser for screenshot-driven match-sheet import.
//

import Foundation
import RefWatchCore
import Supabase
import UIKit

final class OpenAIMatchSheetImportService: MatchSheetImportProviding {
  private static let defaultRequestTimeout: TimeInterval = 90
  private static let functionName = "match-sheet-parse"

  private let clientProvider: SupabaseClientProviding
  private let environmentLoader: () throws -> SupabaseEnvironment
  private let session: URLSession

  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    environmentLoader: @escaping () throws -> SupabaseEnvironment = { try SupabaseEnvironment.load() },
    session: URLSession = .shared)
  {
    self.clientProvider = clientProvider
    self.environmentLoader = environmentLoader
    self.session = session
  }

  static func fromBundleIfAvailable() -> OpenAIMatchSheetImportService? {
    guard TestEnvironment.isRunningTests == false else {
      return nil
    }
    guard Secrets.assistantProxyIsConfigured else {
      return nil
    }
    return OpenAIMatchSheetImportService()
  }

  func parseMatchSheet(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) async throws -> MatchSheetImportResult
  {
    guard images.isEmpty == false else {
      throw MatchSheetImportServiceError.emptySelection
    }

    let payload = Self.buildPayload(
      side: side,
      expectedTeamName: expectedTeamName,
      images: images)
    let request = try await self.makeRequest(payload: payload)
    let (data, response) = try await self.session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw MatchSheetImportServiceError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw MatchSheetImportServiceError.http(
        status: httpResponse.statusCode,
        body: Self.extractErrorMessage(from: data))
    }

    do {
      var result = try Self.jsonDecoder().decode(MatchSheetImportResult.self, from: data)
      result.parsedSheet.status = .draft
      result.parsedSheet = result.parsedSheet.normalized()
      return result
    } catch {
      throw MatchSheetImportServiceError.invalidResponse
    }
  }
}

#if DEBUG
extension OpenAIMatchSheetImportService {
  enum Testing {
    static func buildPayload(
      side: MatchSheetSide,
      expectedTeamName: String?,
      images: [AssistantImageAttachment]) -> MatchSheetImportPayload
    {
      OpenAIMatchSheetImportService.buildPayload(
        side: side,
        expectedTeamName: expectedTeamName,
        images: images)
    }

    static func encodePayload(_ payload: MatchSheetImportPayload) throws -> Data {
      try jsonEncoder().encode(payload)
    }
  }
}
#endif

extension OpenAIMatchSheetImportService {
  struct MatchSheetImportPayload: Encodable, Equatable {
    struct ImagePart: Encodable, Equatable {
      let type = "input_image"
      let imageURL: String
      let detail: AssistantImageAttachment.Detail.RawValue
      let filename: String

      enum CodingKeys: String, CodingKey {
        case type
        case imageURL = "image_url"
        case detail
        case filename
      }
    }

    let side: MatchSheetSide.RawValue
    let expectedTeamName: String?
    let images: [ImagePart]

    enum CodingKeys: String, CodingKey {
      case side
      case expectedTeamName = "expected_team_name"
      case images
    }
  }

  static func buildPayload(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) -> MatchSheetImportPayload
  {
    MatchSheetImportPayload(
      side: side.rawValue,
      expectedTeamName: expectedTeamName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      images: images.map { image in
        MatchSheetImportPayload.ImagePart(
          imageURL: image.dataURL,
          detail: image.detail.rawValue,
          filename: image.filename)
      })
  }

  func makeRequest(payload: MatchSheetImportPayload) async throws -> URLRequest {
    let environment = try self.environmentLoader()
    let client = try await self.clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw MatchSheetImportServiceError.unsupportedClient
    }

    let session: Session
    do {
      session = try await supabaseClient.auth.session
    } catch {
      throw MatchSheetImportServiceError.sessionUnavailable
    }

    return try Self.buildRequest(
      environment: environment,
      accessToken: session.accessToken,
      payload: payload)
  }

  static func edgeFunctionURL(for supabaseURL: URL) -> URL {
    supabaseURL
      .appendingPathComponent("functions")
      .appendingPathComponent("v1")
      .appendingPathComponent(Self.functionName)
  }

  static func jsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    return encoder
  }

  static func buildRequest(
    environment: SupabaseEnvironment,
    accessToken: String,
    payload: MatchSheetImportPayload) throws -> URLRequest
  {
    var request = URLRequest(url: Self.edgeFunctionURL(for: environment.url))
    request.httpMethod = "POST"
    request.timeoutInterval = Self.defaultRequestTimeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(environment.anonKey, forHTTPHeaderField: "apikey")
    request.setValue("ios", forHTTPHeaderField: "X-RefWatch-Client")
    request.httpBody = try Self.jsonEncoder().encode(payload)
    return request
  }

  static func jsonDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoWithoutFraction = ISO8601DateFormatter()
    isoWithoutFraction.formatOptions = [.withInternetDateTime]
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      if let date = isoWithFraction.date(from: value) ?? isoWithoutFraction.date(from: value) {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid date string: \(value)")
    }
    return decoder
  }

  static func extractErrorMessage(from data: Data) -> String? {
    guard data.isEmpty == false else { return nil }
    if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let message = payload["message"] as? String, message.isEmpty == false {
        return message
      }
      if let error = payload["error"] as? String, error.isEmpty == false {
        return error
      }
    }
    return String(data: data, encoding: .utf8)
  }
}

enum MatchSheetImportServiceFactory {
  static func makeDefault() -> MatchSheetImportProviding? {
    if let uiTestMode = TestEnvironment.matchSheetImportUITestMode {
      return UITestMatchSheetImportService(mode: uiTestMode)
    }
    return OpenAIMatchSheetImportService.fromBundleIfAvailable()
  }
}

private final class UITestMatchSheetImportService: MatchSheetImportProviding {
  private enum Constants {
    static let failureMessage = "The parser request failed with a temporary upstream error."
  }

  private static let lock = NSLock()
  private static var attemptsByMode: [MatchSheetImportUITestMode: Int] = [:]

  private let mode: MatchSheetImportUITestMode

  init(mode: MatchSheetImportUITestMode) {
    self.mode = mode
  }

  func parseMatchSheet(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) async throws -> MatchSheetImportResult
  {
    if self.mode == .failOnceThenSuccess, Self.shouldFailFirstAttempt(for: self.mode) {
      throw MatchSheetImportServiceError.http(status: 502, body: Constants.failureMessage)
    }

    let normalizedTeamName = expectedTeamName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
      ?? (side == .home ? "UI Test Home" : "UI Test Away")
    let starters: [MatchSheetPlayerEntry] = [
      MatchSheetPlayerEntry(displayName: "Alex Starter", shirtNumber: 9, position: "FW", notes: nil, sortOrder: 0),
      MatchSheetPlayerEntry(displayName: "Jordan Starter", shirtNumber: 8, position: "CM", notes: "Captain", sortOrder: 1),
    ]
    let substitutes: [MatchSheetPlayerEntry] = [
      MatchSheetPlayerEntry(displayName: "Riley Bench", shirtNumber: nil, position: nil, notes: "Number unreadable", sortOrder: 0),
    ]
    let staff: [MatchSheetStaffEntry] = [
      MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Head Coach", notes: nil, sortOrder: 0, category: .staff),
      MatchSheetStaffEntry(displayName: "Morgan Physio", roleLabel: "Physio", notes: nil, sortOrder: 1, category: .staff),
    ]
    let otherMembers: [MatchSheetStaffEntry] = [
      MatchSheetStaffEntry(displayName: "Casey Analyst", roleLabel: "Analyst", notes: nil, sortOrder: 0, category: .otherMember),
    ]

    return MatchSheetImportResult(
      parsedSheet: ScheduledMatchSheet(
        sourceTeamName: normalizedTeamName,
        status: .draft,
        starters: starters,
        substitutes: substitutes,
        staff: staff,
        otherMembers: otherMembers,
        updatedAt: Date()).normalized(),
      warnings: [
        MatchSheetImportWarning(
          code: .nonIntegerShirtNumber,
          message: "One substitute had an unreadable shirt number and it was cleared."),
      ],
      extractedTeamName: normalizedTeamName,
      terminalStatus: .completed)
  }

  private static func shouldFailFirstAttempt(for mode: MatchSheetImportUITestMode) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    let nextAttempt = (self.attemptsByMode[mode] ?? 0) + 1
    self.attemptsByMode[mode] = nextAttempt
    return nextAttempt == 1
  }
}

enum MatchSheetImportUITestMode: String {
  case success = "success"
  case failOnceThenSuccess = "fail_once_then_success"
}

private extension String {
  var nilIfEmpty: String? {
    self.isEmpty ? nil : self
  }
}
