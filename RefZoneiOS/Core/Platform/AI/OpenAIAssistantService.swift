//
//  OpenAIAssistantService.swift
//  RefZoneiOS
//
//  Uses OpenAI's Responses API for streaming chat completions.
//  Migrated from Chat Completions API on 2025-10-09.
//

import Foundation

final class OpenAIAssistantService: AssistantProviding {
  private enum RequestBuildError: LocalizedError {
    case emptyConversation

    var errorDescription: String? {
      switch self {
      case .emptyConversation:
        return "Cannot build OpenAI payload without at least one user message."
      }
    }
  }

  private enum ServiceError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String?)

    var errorDescription: String? {
      switch self {
      case .invalidResponse:
        return "OpenAI request returned a non-HTTP response."
      case let .http(status, body):
        return "OpenAI responded with HTTP \(status): \(body ?? "no body")"
      }
    }
  }

  private static let responsesURL = URL(string: "https://api.openai.com/v1/responses")!
  private static let defaultRequestTimeout: TimeInterval = 60

  private let apiKey: String
  private let model: String
  private let systemPrompt: String

  init(
    apiKey: String,
    model: String = "gpt-4o-mini",
    systemPrompt: String = "You are RefWatch's helpful football referee assistant on iOS."
  ) {
    self.apiKey = apiKey
    self.model = model
    self.systemPrompt = systemPrompt
  }

  static func fromBundleIfAvailable() -> OpenAIAssistantService? {
    if let key = Secrets.openAIKey, !key.isEmpty {
      return OpenAIAssistantService(apiKey: key)
    }
    return nil
  }

  func streamResponse(for messages: [ChatMessage]) -> AsyncStream<String> {
    AsyncStream { continuation in
      Task {
        defer { continuation.finish() }

        do {
          Self.log("Preparing Responses API request with \(messages.count) chat messages")
          let payload = try Self.buildResponsesPayload(
            model: model,
            systemPrompt: systemPrompt,
            messages: messages
          )
          Self.log("Built payload with \(payload.input.count) input items")
          let request = try Self.makeRequest(apiKey: apiKey, payload: payload)
          Self.log("Dispatching streaming request to \(Self.responsesURL.absoluteString)")
          try await Self.streamResponses(request: request, continuation: continuation)
        } catch {
          #if DEBUG
          debugPrint("OpenAIAssistantService stream error:", error)
          #endif
        }
      }
    }
  }
}

#if DEBUG
extension OpenAIAssistantService {
  enum Testing {
    static func buildPayload(
      model: String,
      systemPrompt: String,
      messages: [ChatMessage]
    ) throws -> ResponsesPayload {
      try buildResponsesPayload(model: model, systemPrompt: systemPrompt, messages: messages)
    }

    static func encodePayload(_ payload: ResponsesPayload) throws -> Data {
      try jsonEncoder().encode(payload)
    }

    static func parseStream(
      lines: [String]
    ) -> (chunks: [String], usage: ResponsesUsage?, shouldTerminate: Bool) {
      var parser = ResponsesStreamParser()
      var output: [String] = []
      for line in lines {
        parser.handle(line: line) { output.append($0) }
        if parser.shouldTerminate {
          break
        }
      }
      parser.finishIfNeeded { output.append($0) }
      return (output, parser.usage, parser.shouldTerminate)
    }
  }
}
#endif

// MARK: - Request Building

private extension OpenAIAssistantService {
  static func buildResponsesPayload(
    model: String,
    systemPrompt: String,
    messages: [ChatMessage]
  ) throws -> ResponsesPayload {
    let inputMessages = messages.compactMap { message -> ResponsesPayload.InputMessage? in
      let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }

      return ResponsesPayload.InputMessage(
        role: message.role.rawValue,
        content: [ResponsesPayload.InputContent(text: trimmed)]
      )
    }

    guard !inputMessages.isEmpty else {
      throw RequestBuildError.emptyConversation
    }

    #if DEBUG
    log("Finalizing payload — instructions length: \(systemPrompt.count), input count: \(inputMessages.count)")
    #endif

    return ResponsesPayload(
      model: model,
      stream: true,
      instructions: systemPrompt,
      input: inputMessages
    )
  }

  static func makeRequest(apiKey: String, payload: ResponsesPayload) throws -> URLRequest {
    var request = URLRequest(url: responsesURL)
    request.httpMethod = "POST"
    request.timeoutInterval = defaultRequestTimeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

    let encoder = jsonEncoder()
    request.httpBody = try encoder.encode(payload)
    #if DEBUG
    if let body = request.httpBody,
       let bodyString = String(data: body, encoding: .utf8) {
      log("Encoded payload: \(bodyString)")
    }
    #endif
    return request
  }

  static func jsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    return encoder
  }

  static func jsonDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  static func log(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("OpenAI[Responses]", message())
    #endif
  }
}

// MARK: - Streaming Pipeline

private extension OpenAIAssistantService {
  // OpenAI Responses API documentation:
  // https://platform.openai.com/docs/api-reference/responses/create
  // Streaming events reference:
  // https://platform.openai.com/docs/guides/streaming-responses
  // Input format reference:
  // https://platform.openai.com/docs/api-reference/responses/input-items
  static func streamResponses(
    request: URLRequest,
    continuation: AsyncStream<String>.Continuation
  ) async throws {
    let (bytes, response) = try await URLSession.shared.bytes(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ServiceError.invalidResponse
    }

    log("Received HTTP status \(httpResponse.statusCode)")

    guard (200...299).contains(httpResponse.statusCode) else {
      let body = await collectErrorBody(from: bytes)
      if let body {
        log("HTTP error body: \(body)")
      }
      throw ServiceError.http(status: httpResponse.statusCode, body: body)
    }

    var parser = ResponsesStreamParser()

    do {
      for try await rawLine in bytes.lines {
        parser.handle(line: rawLine, continuation: continuation)
        if parser.shouldTerminate || Task.isCancelled {
          break
        }
      }
      parser.finishIfNeeded(continuation: continuation)
    } catch {
      parser.finishIfNeeded(continuation: continuation)
      throw error
    }

    if let usage = parser.usage {
      #if DEBUG
      debugPrint(
        "OpenAI usage — input: \(usage.inputTokens ?? 0), output: \(usage.outputTokens ?? 0), total: \(usage.totalTokens ?? 0)"
      )
      #endif
    }
  }

  static func collectErrorBody(from bytes: URLSession.AsyncBytes) async -> String? {
    var data = Data()
    do {
      for try await byte in bytes {
        data.append(byte)
      }
    } catch {
      return nil
    }

    guard !data.isEmpty else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

// MARK: - Types

private extension OpenAIAssistantService {
  internal struct ResponsesPayload: Encodable {
    let model: String
    let stream: Bool
    let instructions: String
    let input: [InputMessage]

    internal struct InputMessage: Encodable {
      let role: String
      let content: [InputContent]
    }

    internal struct InputContent: Encodable {
      let type = "input_text"
      let text: String
    }
  }

  internal struct OutputTextDeltaEvent: Decodable {
    let delta: String?
  }

  internal struct ResponseDoneEvent: Decodable {
    internal struct ResponseSummary: Decodable {
      let id: String?
      let status: String?
      let usage: Usage?
    }

    internal struct Usage: Decodable {
      let totalTokens: Int?
      let inputTokens: Int?
      let outputTokens: Int?
    }

    let response: ResponseSummary?
  }

  internal struct ResponseCompletedEvent: Decodable {
    internal struct ResponseSummary: Decodable {
      let id: String?
      let status: String?
      let usage: Usage?
    }

    internal struct Usage: Decodable {
      let totalTokens: Int?
      let inputTokens: Int?
      let outputTokens: Int?
    }

    let response: ResponseSummary?
  }

  internal struct ErrorEvent: Decodable {
    internal struct ErrorPayload: Decodable {
      let message: String?
      let code: String?
      let type: String?
    }

    let error: ErrorPayload?
  }

  internal struct ResponsesUsage {
    let totalTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
  }

  internal struct ResponsesStreamParser {
    private var currentEvent: String?
    private var dataFragments: [String] = []

    var shouldTerminate = false
    var usage: ResponsesUsage?

    mutating func handle(line rawLine: String, continuation: AsyncStream<String>.Continuation) {
      handle(line: rawLine) { continuation.yield($0) }
    }

    mutating func handle(line rawLine: String, yield: (String) -> Void) {
      let sanitizedLine = sanitize(rawLine)
      #if DEBUG
      OpenAIAssistantService.log("SSE line: \(sanitizedLine)")
      #endif
      guard !sanitizedLine.isEmpty else {
        finalizeCurrentEvent(yield: yield)
        return
      }

      if sanitizedLine.hasPrefix(":") {
        return
      }

      if let eventType = parseField("event", from: sanitizedLine) {
        if currentEvent != nil || !dataFragments.isEmpty {
          finalizeCurrentEvent(yield: yield)
        }
        currentEvent = eventType
        return
      }

      if let dataPart = parseField("data", from: sanitizedLine) {
        dataFragments.append(dataPart)
        return
      }
    }

    mutating func finishIfNeeded(continuation: AsyncStream<String>.Continuation) {
      finishIfNeeded { continuation.yield($0) }
    }

    mutating func finishIfNeeded(_ yield: (String) -> Void) {
      if !dataFragments.isEmpty || currentEvent != nil {
        finalizeCurrentEvent(yield: yield)
      }
    }

    private mutating func finalizeCurrentEvent(
      yield: (String) -> Void
    ) {
      guard let eventType = currentEvent else {
        dataFragments.removeAll(keepingCapacity: true)
        return
      }

      let payload = dataFragments.joined(separator: "\n")
      currentEvent = nil
      dataFragments.removeAll(keepingCapacity: true)

      guard !payload.isEmpty else { return }
      handle(event: eventType, payload: payload, yield: yield)
    }

    private mutating func handle(
      event: String,
      payload: String,
      yield: (String) -> Void
    ) {
      #if DEBUG
      OpenAIAssistantService.log("Processing SSE event: \(event)")
      #endif
      guard let data = payload.data(using: .utf8) else { return }
      let decoder = OpenAIAssistantService.jsonDecoder()

      switch event {
      case "response.output_text.delta":
        if let deltaEvent = try? decoder.decode(OutputTextDeltaEvent.self, from: data),
           let delta = deltaEvent.delta,
           !delta.isEmpty {
          #if DEBUG
          OpenAIAssistantService.log("Delta chunk received (\(delta.count) chars)")
          #endif
          yield(delta)
        }

      case "response.done":
        if let doneEvent = try? decoder.decode(ResponseDoneEvent.self, from: data),
           let summary = doneEvent.response,
           let usage = summary.usage {
          self.usage = ResponsesUsage(
            totalTokens: usage.totalTokens,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens
          )
        }
        #if DEBUG
        OpenAIAssistantService.log("response.done event received")
        #endif
        shouldTerminate = true

      case "response.completed":
        if let completedEvent = try? decoder.decode(ResponseCompletedEvent.self, from: data),
           let summary = completedEvent.response,
           let usage = summary.usage {
          self.usage = ResponsesUsage(
            totalTokens: usage.totalTokens,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens
          )
        }
        #if DEBUG
        OpenAIAssistantService.log("response.completed event received")
        #endif
        shouldTerminate = true

      case "response.failed":
        if let failedEvent = try? decoder.decode(ErrorEvent.self, from: data),
           let message = failedEvent.error?.message {
          #if DEBUG
          debugPrint("OpenAI Responses stream failure:", message)
          OpenAIAssistantService.log("response.failed payload: \(payload)")
          #endif
        }
        shouldTerminate = true

      case "error":
        if let errorEvent = try? decoder.decode(ErrorEvent.self, from: data),
           let message = errorEvent.error?.message {
          #if DEBUG
          debugPrint("OpenAI Responses stream error:", message)
          OpenAIAssistantService.log("error event payload: \(payload)")
          #endif
        }
        shouldTerminate = true

      default:
        #if DEBUG
        debugPrint("OpenAI Responses stream ignored event:", event)
        #endif
      }
    }

    private func parseField(_ field: String, from line: String) -> String? {
      let prefix = "\(field):"
      guard line.hasPrefix(prefix) else { return nil }
      let start = line.index(line.startIndex, offsetBy: prefix.count)
      let remainder = line[start...]
      if remainder.first == " " {
        return String(remainder.dropFirst())
      }
      return String(remainder)
    }

    private func sanitize(_ line: String) -> String {
      if line.hasSuffix("\r") {
        return String(line.dropLast())
      }
      return line
    }
  }
}
