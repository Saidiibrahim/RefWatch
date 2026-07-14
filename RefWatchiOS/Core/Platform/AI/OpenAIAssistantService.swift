//
//  AssistantProxyContract.swift
//  RefWatchiOS
//
//  Streams assistant responses through the authenticated backend Worker.
//

import Foundation

enum AssistantProxyContract {
  private static let defaultModel = "gpt-5.4-mini"

  static func fromBundleIfAvailable() -> (any AssistantProviding)? {
    guard TestEnvironment.isRunningTests == false else { return nil }
    guard let client = BackendServiceRegistry.client else { return nil }
    return BackendAssistantService(client: client)
  }
}
#if DEBUG
extension AssistantProxyContract {
  enum Testing {
    static func buildPayload(
      systemPrompt: String,
      messages: [ChatMessage]) throws -> AssistantProxyPayload
    {
      try buildProxyPayload(
        model: AssistantProxyContract.defaultModel,
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

    static func decodeStreamLines(chunks: [Data]) throws -> [String] {
      var lineBuffer = SSELineBuffer()
      var output: [String] = []
      for chunk in chunks {
        output.append(contentsOf: try lineBuffer.append(chunk))
      }
      output.append(contentsOf: try lineBuffer.finish())
      return output
    }
  }
}
#endif

// MARK: - Request Building

extension AssistantProxyContract {
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

// MARK: - Types

extension AssistantProxyContract {
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

  struct ResponseIncompleteEvent: Decodable {
    struct ResponseSummary: Decodable {
      struct IncompleteDetails: Decodable {
        let reason: String?
      }

      let incompleteDetails: IncompleteDetails?
    }

    let response: ResponseSummary?
  }

  struct SSELineBuffer {
    private var buffer = Data()

    var isEmpty: Bool {
      self.buffer.isEmpty
    }

    mutating func append(_ data: Data) throws -> [String] {
      guard data.isEmpty == false else { return [] }
      self.buffer.append(data)

      var lines: [String] = []
      while let newlineIndex = self.buffer.firstIndex(of: 0x0A) {
        let lineData = self.buffer[..<newlineIndex]
        lines.append(try self.decodeLine(Data(lineData)))
        let nextIndex = self.buffer.index(after: newlineIndex)
        self.buffer.removeSubrange(..<nextIndex)
      }
      return lines
    }

    mutating func finish() throws -> [String] {
      guard self.buffer.isEmpty == false else { return [] }
      let remainder = self.buffer
      self.buffer.removeAll(keepingCapacity: true)
      return [try self.decodeLine(remainder)]
    }

    private func decodeLine(_ data: Data) throws -> String {
      guard var line = String(data: data, encoding: .utf8) else {
        throw AssistantServiceError.invalidResponse
      }
      if line.hasSuffix("\r") {
        line.removeLast()
      }
      return line
    }
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
      let decoder = AssistantProxyContract.jsonDecoder()

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

      case "response.incomplete":
        let reason = (try? decoder.decode(ResponseIncompleteEvent.self, from: data))?
          .response?
          .incompleteDetails?
          .reason
        self.terminalError = .streamFailed(message: self.incompleteMessage(for: reason))
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
        AssistantProxyContract.log("Ignoring SSE event: \(event)")
      }
    }

    private func incompleteMessage(for reason: String?) -> String {
      switch reason {
      case "max_output_tokens":
        return "The assistant stopped before finishing the answer."
      case let .some(reason) where reason.isEmpty == false:
        return "The assistant response was incomplete (\(reason))."
      default:
        return "The assistant response was incomplete."
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
