//
//  AssistantService.swift
//  RefZoneiOS
//

import Foundation

protocol AssistantProviding {
    func streamResponse(for messages: [ChatMessage]) -> AsyncStream<String>
}

final class StubAssistantService: AssistantProviding {
    func streamResponse(for messages: [ChatMessage]) -> AsyncStream<String> {
        let userText = messages.last(where: { $0.role == .user })?.text ?? ""
        let reply = "You said: \(userText)"
        return AsyncStream { continuation in
            Task {
                let chunkSize = max(4, reply.count / 3)
                var start = reply.startIndex
                while start < reply.endIndex {
                    let end = reply.index(start, offsetBy: chunkSize, limitedBy: reply.endIndex) ?? reply.endIndex
                    let chunk = String(reply[start..<end])
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                    continuation.yield(chunk)
                    if end == reply.endIndex { break }
                    start = end
                }
                continuation.finish()
            }
        }
    }
}
