//
//  AssistantService.swift
//  RefWatchiOS
//

import Foundation

struct AssistantResponseStream {
  let stream: AsyncThrowingStream<String, Error>
  private let cancelHandler: @Sendable () -> Void

  init(
    stream: AsyncThrowingStream<String, Error>,
    cancelHandler: @escaping @Sendable () -> Void = {})
  {
    self.stream = stream
    self.cancelHandler = cancelHandler
  }

  func cancel() {
    self.cancelHandler()
  }
}

protocol AssistantProviding {
  func streamResponse(for messages: [ChatMessage]) async throws -> AssistantResponseStream
}

enum AssistantServiceError: LocalizedError, Equatable {
  case emptyConversation
  case invalidResponse
  case unsupportedClient
  case sessionUnavailable
  case http(status: Int, body: String?)
  case streamFailed(message: String)

  var errorDescription: String? {
    switch self {
    case .emptyConversation:
      return "Write a message or attach an image before sending."
    case .invalidResponse:
      return "The assistant returned an invalid response."
    case .unsupportedClient:
      return "Assistant transport is unavailable on this build."
    case .sessionUnavailable:
      return "Sign in again to use the assistant."
    case let .http(status, _):
      if status == 401 {
        return "Sign in again to use the assistant."
      }
      return "The assistant request failed with HTTP \(status)."
    case let .streamFailed(message):
      return message
    }
  }
}

final class StubAssistantService: AssistantProviding {
  func streamResponse(for messages: [ChatMessage]) async throws -> AssistantResponseStream {
    let lastUserMessage = messages.last(where: { $0.role == .user })
    let text = lastUserMessage?.text ?? ""
    let imageCount = lastUserMessage?.imageAttachment == nil ? 0 : 1
    let reply: String
    if imageCount > 0, text.isEmpty == false {
      reply = "Stub mode received your prompt and 1 image, but the live assistant proxy is unavailable."
    } else if imageCount > 0 {
      reply = "Stub mode received 1 image, but the live assistant proxy is unavailable."
    } else {
      reply = "You said: \(text)"
    }

    let cancellation = StubResponseCancellation()

    let stream = AsyncThrowingStream<String, Error> { continuation in
      Task {
        let chunkSize = max(4, reply.count / 3)
        var start = reply.startIndex
        while start < reply.endIndex {
          if cancellation.isCancelled {
            continuation.finish()
            return
          }

          let end = reply.index(start, offsetBy: chunkSize, limitedBy: reply.endIndex) ?? reply.endIndex
          continuation.yield(String(reply[start..<end]))
          if end == reply.endIndex {
            continuation.finish()
            return
          }
          start = end
          try? await Task.sleep(nanoseconds: 200_000_000)
        }

        continuation.finish()
      }
    }

    return AssistantResponseStream(
      stream: stream,
      cancelHandler: {
        cancellation.cancel()
      })
  }
}

private final class StubResponseCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false

  var isCancelled: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.cancelled
  }

  func cancel() {
    self.lock.lock()
    self.cancelled = true
    self.lock.unlock()
  }
}
