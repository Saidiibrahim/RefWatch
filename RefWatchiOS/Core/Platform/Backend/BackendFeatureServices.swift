import Foundation
import RefWatchCore

/// App-composition handoff used by feature factories that are created by SwiftUI later.
enum BackendServiceRegistry {
  nonisolated(unsafe) static var client: BackendAPIClient?
  nonisolated(unsafe) static var referenceCatalog: (any ReferenceCatalogServing)?
}

final class BackendAssistantService: AssistantProviding {
  private let api: BackendAssistantAPI
  private let systemPrompt: String

  init(
    client: BackendAPIClient,
    systemPrompt: String = "You are RefWatch's helpful football referee assistant on iOS. Answer concisely using text and images when provided.")
  {
    api = BackendAssistantAPI(client: client)
    self.systemPrompt = systemPrompt
  }

  func streamResponse(for messages: [ChatMessage]) async throws -> AssistantResponseStream {
    let payload = try AssistantProxyContract.buildProxyPayload(
      model: "gpt-5.4-mini",
      systemPrompt: systemPrompt,
      messages: messages)
    let source = try await api.streamResponse(for: payload)
    let cancellation = BackendStreamCancellation()
    let output = AsyncThrowingStream<String, Error> { continuation in
      let task = Task {
        do {
          var buffer = AssistantProxyContract.SSELineBuffer()
          var parser = AssistantProxyContract.ResponsesStreamParser()
          for try await chunk in source.bytes {
            try Task.checkCancellation()
            for line in try buffer.append(chunk) {
              parser.handle(line: line, continuation: continuation)
              if parser.shouldTerminate { break }
            }
            if parser.shouldTerminate { break }
          }
          for line in try buffer.finish() { parser.handle(line: line, continuation: continuation) }
          parser.finishIfNeeded(continuation: continuation)
          if let error = parser.terminalError { continuation.finish(throwing: error) }
          else { continuation.finish() }
        } catch is CancellationError {
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      cancellation.task = task
      continuation.onTermination = { _ in task.cancel() }
    }
    return AssistantResponseStream(stream: output, cancelHandler: { cancellation.cancel() })
  }
}

final class BackendMatchSheetImportService: MatchSheetImportProviding {
  private let api: BackendMatchSheetParseAPI
  init(client: BackendAPIClient) { api = BackendMatchSheetParseAPI(client: client) }

  func parseMatchSheet(
    side: MatchSheetSide,
    expectedTeamName: String?,
    images: [AssistantImageAttachment]) async throws -> MatchSheetImportResult
  {
    guard images.isEmpty == false else { throw MatchSheetImportServiceError.emptySelection }
    let payload = MatchSheetParseContract.buildPayload(
      side: side,
      expectedTeamName: expectedTeamName,
      images: images)
    var result: MatchSheetImportResult = try await api.parse(payload)
    result.parsedSheet.status = .draft
    result.parsedSheet = result.parsedSheet.normalized()
    return result
  }
}

private final class BackendStreamCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var storedTask: Task<Void, Never>?
  var task: Task<Void, Never>? {
    get { lock.withLock { storedTask } }
    set { lock.withLock { storedTask = newValue } }
  }
  func cancel() { task?.cancel() }
}
