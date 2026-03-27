//
//  OpenAIAssistantService.swift
//  RefWatchiOS
//
//  Streams assistant responses through the authenticated Supabase edge proxy.
//

import Foundation
import Supabase

final class OpenAIAssistantService: AssistantProviding {
  private static let defaultRequestTimeout: TimeInterval = 60
  private static let functionName = "assistant-responses"
  private static let defaultModel = "gpt-5.4-mini"

  private let clientProvider: SupabaseClientProviding
  private let environmentLoader: () throws -> SupabaseEnvironment
  private let systemPrompt: String

  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    environmentLoader: @escaping () throws -> SupabaseEnvironment = { try SupabaseEnvironment.load() },
    systemPrompt: String = "You are RefWatch's helpful football referee assistant on iOS. Answer concisely using text and images when provided.")
  {
    self.clientProvider = clientProvider
    self.environmentLoader = environmentLoader
    self.systemPrompt = systemPrompt
  }

  static func fromBundleIfAvailable() -> OpenAIAssistantService? {
    guard TestEnvironment.isRunningTests == false else {
      return nil
    }
    guard Secrets.assistantProxyIsConfigured else {
      return nil
    }
    return OpenAIAssistantService()
  }

  func streamResponse(for messages: [ChatMessage]) async throws -> AssistantResponseStream {
    let payload = try Self.buildProxyPayload(
      model: Self.defaultModel,
      systemPrompt: self.systemPrompt,
      messages: messages)
    let request = try await self.makeRequest(payload: payload)
    return Self.makeStreamingResponse(for: request)
  }
}

#if DEBUG
extension OpenAIAssistantService {
  enum Testing {
    static func buildPayload(
      systemPrompt: String,
      messages: [ChatMessage]) throws -> AssistantProxyPayload
    {
      try buildProxyPayload(
        model: OpenAIAssistantService.defaultModel,
        systemPrompt: systemPrompt,
        messages: messages)
    }

    static func encodePayload(_ payload: AssistantProxyPayload) throws -> Data {
      try jsonEncoder().encode(payload)
    }

    static func parseStream(
      lines: [String]) -> (chunks: [String], usage: ResponsesUsage?, shouldTerminate: Bool, terminalError: AssistantServiceError?)
    {
      var parser = ResponsesStreamParser()
      var output: [String] = []
      for line in lines {
        parser.handle(line: line) { output.append($0) }
        if parser.shouldTerminate {
          break
        }
      }
      parser.finishIfNeeded { output.append($0) }
      return (output, parser.usage, parser.shouldTerminate, parser.terminalError)
    }
  }
}
#endif

// MARK: - Request Building

extension OpenAIAssistantService {
  static func buildProxyPayload(
    model: String,
    systemPrompt: String,
    messages: [ChatMessage]) throws -> AssistantProxyPayload
  {
    let inputMessages = messages.compactMap { message -> AssistantProxyPayload.Message? in
      let content = message.content.compactMap { part -> AssistantProxyPayload.Content? in
        switch part {
        case let .text(text):
          let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
          guard trimmed.isEmpty == false else { return nil }
          let type = message.role == .assistant ? "output_text" : "input_text"
          return AssistantProxyPayload.Content(type: type, text: trimmed)
        case let .image(attachment):
          guard message.role == .user else { return nil }
          return AssistantProxyPayload.Content(
            type: "input_image",
            imageURL: attachment.dataURL,
            detail: attachment.detail.rawValue)
        }
      }

      guard content.isEmpty == false else { return nil }
      return AssistantProxyPayload.Message(role: message.role.rawValue, content: content)
    }

    guard inputMessages.isEmpty == false else {
      throw AssistantServiceError.emptyConversation
    }

    return AssistantProxyPayload(
      model: model,
      stream: true,
      store: false,
      instructions: systemPrompt,
      messages: inputMessages)
  }

  func makeRequest(payload: AssistantProxyPayload) async throws -> URLRequest {
    let environment = try self.environmentLoader()
    let client = try await self.clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw AssistantServiceError.unsupportedClient
    }

    let session: Session
    do {
      session = try await supabaseClient.auth.session
    } catch {
      throw AssistantServiceError.sessionUnavailable
    }

    var request = URLRequest(url: Self.edgeFunctionURL(for: environment.url))
    request.httpMethod = "POST"
    request.timeoutInterval = Self.defaultRequestTimeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("ios", forHTTPHeaderField: "X-RefWatch-Client")
    request.httpBody = try Self.jsonEncoder().encode(payload)
    return request
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

extension OpenAIAssistantService {
  static func makeStreamingResponse(for request: URLRequest) -> AssistantResponseStream {
    let relay = ResponsesURLSessionStreamRelay(request: request)
    relay.start()
    return AssistantResponseStream(
      stream: relay.stream,
      cancelHandler: {
        relay.cancel()
      })
  }

  private final class ResponsesURLSessionStreamRelay: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let request: URLRequest
    private let lock = NSLock()
    private let continuation: AsyncThrowingStream<String, Error>.Continuation

    let stream: AsyncThrowingStream<String, Error>

    private var parser = ResponsesStreamParser()
    private var buffer = ""
    private var errorBody = Data()
    private var statusCode: Int?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var finished = false
    private var cancelled = false

    init(request: URLRequest) {
      self.request = request
      let streamPair = Self.makeStream()
      self.stream = streamPair.stream
      self.continuation = streamPair.continuation
      super.init()
    }

    func start() {
      let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
      let task = session.dataTask(with: self.request)

      self.lock.lock()
      self.session = session
      self.task = task
      self.lock.unlock()

      task.resume()
    }

    func cancel() {
      let task: URLSessionDataTask?
      let session: URLSession?

      self.lock.lock()
      guard self.finished == false else {
        self.lock.unlock()
        return
      }
      self.cancelled = true
      task = self.task
      session = self.session
      self.lock.unlock()

      self.completeIfNeeded()
      task?.cancel()
      session?.invalidateAndCancel()
    }

    func urlSession(
      _ session: URLSession,
      dataTask: URLSessionDataTask,
      didReceive response: URLResponse,
      completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
      guard let httpResponse = response as? HTTPURLResponse else {
        self.completeIfNeeded(throwing: AssistantServiceError.invalidResponse)
        completionHandler(.cancel)
        return
      }

      self.lock.lock()
      self.statusCode = httpResponse.statusCode
      let shouldAllow = self.finished == false
      self.lock.unlock()

      completionHandler(shouldAllow ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
      var lines: [String] = []
      var shouldIgnore = false

      self.lock.lock()
      if self.finished {
        shouldIgnore = true
      } else if let statusCode = self.statusCode, (200...299).contains(statusCode) == false {
        self.errorBody.append(data)
      } else {
        self.buffer.append(String(decoding: data, as: UTF8.self))
        while let newlineRange = self.buffer.range(of: "\n") {
          let line = String(self.buffer[..<newlineRange.lowerBound])
          lines.append(line)
          self.buffer.removeSubrange(self.buffer.startIndex..<newlineRange.upperBound)
        }
      }
      self.lock.unlock()

      if shouldIgnore {
        return
      }

      for line in lines {
        self.process(line: line)
      }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      var statusCode: Int?
      var parserTerminalError: AssistantServiceError?
      var emittedChunks: [String] = []
      var body: String?
      var finished = false
      var cancelled = false

      self.lock.lock()
      statusCode = self.statusCode
      finished = self.finished
      cancelled = self.cancelled

      if finished == false, let statusCode, (200...299).contains(statusCode) {
        if self.buffer.isEmpty == false {
          self.parser.handle(line: self.buffer) { emittedChunks.append($0) }
          self.buffer.removeAll(keepingCapacity: true)
        }
        self.parser.finishIfNeeded { emittedChunks.append($0) }
        parserTerminalError = self.parser.terminalError
      }

      if self.errorBody.isEmpty == false {
        body = String(data: self.errorBody, encoding: .utf8)
      }
      self.lock.unlock()

      emittedChunks.forEach { self.continuation.yield($0) }

      guard finished == false else { return }
      guard cancelled == false else {
        self.completeIfNeeded()
        return
      }

      guard let statusCode else {
        self.completeIfNeeded(throwing: AssistantServiceError.invalidResponse)
        return
      }

      if (200...299).contains(statusCode) == false {
        self.completeIfNeeded(throwing: AssistantServiceError.http(status: statusCode, body: body))
        return
      }

      if let parserTerminalError {
        self.completeIfNeeded(throwing: parserTerminalError)
        return
      }

      if let error = error as NSError? {
        if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled {
          self.completeIfNeeded()
        } else {
          self.completeIfNeeded(throwing: error)
        }
        return
      }

      self.completeIfNeeded()
    }

    private func process(line: String) {
      var emittedChunks: [String] = []
      var shouldTerminate = false
      var terminalError: AssistantServiceError?

      self.lock.lock()
      guard self.finished == false else {
        self.lock.unlock()
        return
      }

      self.parser.handle(line: line) { emittedChunks.append($0) }
      shouldTerminate = self.parser.shouldTerminate
      terminalError = self.parser.terminalError
      self.lock.unlock()

      emittedChunks.forEach { self.continuation.yield($0) }

      guard shouldTerminate else { return }

      if let terminalError {
        self.completeIfNeeded(throwing: terminalError)
      } else {
        self.completeIfNeeded()
      }

      self.task?.cancel()
      self.session?.invalidateAndCancel()
    }

    private func completeIfNeeded(throwing error: Error? = nil) {
      self.lock.lock()
      guard self.finished == false else {
        self.lock.unlock()
        return
      }
      self.finished = true
      self.lock.unlock()

      if let error {
        self.continuation.finish(throwing: error)
      } else {
        self.continuation.finish()
      }
    }

    private static func makeStream() -> (
      stream: AsyncThrowingStream<String, Error>,
      continuation: AsyncThrowingStream<String, Error>.Continuation)
    {
      var capturedContinuation: AsyncThrowingStream<String, Error>.Continuation!
      let stream = AsyncThrowingStream<String, Error> { continuation in
        capturedContinuation = continuation
      }
      return (stream, capturedContinuation)
    }
  }
}

// MARK: - Types

extension OpenAIAssistantService {
  struct AssistantProxyPayload: Encodable, Equatable {
    let model: String
    let stream: Bool
    let store: Bool
    let instructions: String
    let messages: [Message]

    struct Message: Encodable, Equatable {
      let role: String
      let content: [Content]
    }

    struct Content: Encodable, Equatable {
      let type: String
      let text: String?
      let imageURL: String?
      let detail: String?

      init(
        type: String,
        text: String? = nil,
        imageURL: String? = nil,
        detail: String? = nil)
      {
        self.type = type
        self.text = text
        self.imageURL = imageURL
        self.detail = detail
      }

      enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
        case detail
      }
    }
  }

  struct StreamEventUsage: Decodable {
    let totalTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
  }

  struct ResponseSummaryEvent: Decodable {
    struct ResponseSummary: Decodable {
      let usage: StreamEventUsage?
    }

    let response: ResponseSummary?
  }

  struct OutputTextDeltaEvent: Decodable {
    let delta: String?
  }

  struct ErrorEvent: Decodable {
    struct ErrorPayload: Decodable {
      let message: String?
    }

    let error: ErrorPayload?
    let response: ResponseFailurePayload?

    struct ResponseFailurePayload: Decodable {
      struct FailureError: Decodable {
        let message: String?
      }

      let error: FailureError?
    }
  }

  struct ResponsesUsage: Equatable {
    let totalTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
  }

  struct ResponsesStreamParser {
    private var currentEvent: String?
    private var dataFragments: [String] = []

    var shouldTerminate = false
    var usage: ResponsesUsage?
    var terminalError: AssistantServiceError?

    mutating func handle(
      line rawLine: String,
      continuation: AsyncThrowingStream<String, Error>.Continuation)
    {
      self.handle(line: rawLine) { continuation.yield($0) }
    }

    mutating func handle(line rawLine: String, yield: (String) -> Void) {
      let sanitizedLine = self.sanitize(rawLine)
      guard sanitizedLine.isEmpty == false else {
        self.finalizeCurrentEvent(yield: yield)
        return
      }

      if sanitizedLine.hasPrefix(":") {
        return
      }

      if let eventType = parseField("event", from: sanitizedLine) {
        if self.currentEvent != nil || self.dataFragments.isEmpty == false {
          self.finalizeCurrentEvent(yield: yield)
        }
        self.currentEvent = eventType
        return
      }

      if let dataPart = parseField("data", from: sanitizedLine) {
        self.dataFragments.append(dataPart)
      }
    }

    mutating func finishIfNeeded(continuation: AsyncThrowingStream<String, Error>.Continuation) {
      self.finishIfNeeded { continuation.yield($0) }
    }

    mutating func finishIfNeeded(_ yield: (String) -> Void) {
      if self.dataFragments.isEmpty == false || self.currentEvent != nil {
        self.finalizeCurrentEvent(yield: yield)
      }
    }

    private mutating func finalizeCurrentEvent(yield: (String) -> Void) {
      guard let eventType = self.currentEvent else {
        self.dataFragments.removeAll(keepingCapacity: true)
        return
      }

      let payload = self.dataFragments.joined(separator: "\n")
      self.currentEvent = nil
      self.dataFragments.removeAll(keepingCapacity: true)

      guard payload.isEmpty == false else { return }
      self.handle(event: eventType, payload: payload, yield: yield)
    }

    private mutating func handle(event: String, payload: String, yield: (String) -> Void) {
      guard let data = payload.data(using: .utf8) else { return }
      let decoder = OpenAIAssistantService.jsonDecoder()

      switch event {
      case "response.output_text.delta":
        if let deltaEvent = try? decoder.decode(OutputTextDeltaEvent.self, from: data),
           let delta = deltaEvent.delta,
           delta.isEmpty == false
        {
          yield(delta)
        }

      case "response.done", "response.completed":
        if let summaryEvent = try? decoder.decode(ResponseSummaryEvent.self, from: data),
           let usage = summaryEvent.response?.usage
        {
          self.usage = ResponsesUsage(
            totalTokens: usage.totalTokens,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens)
        }
        self.shouldTerminate = true

      case "response.failed", "error":
        if let errorEvent = try? decoder.decode(ErrorEvent.self, from: data) {
          let message =
            errorEvent.error?.message ??
            errorEvent.response?.error?.message ??
            "The assistant could not finish that response."
          self.terminalError = .streamFailed(message: message)
        } else {
          self.terminalError = .streamFailed(message: "The assistant could not finish that response.")
        }
        self.shouldTerminate = true

      default:
        OpenAIAssistantService.log("Ignoring SSE event: \(event)")
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
