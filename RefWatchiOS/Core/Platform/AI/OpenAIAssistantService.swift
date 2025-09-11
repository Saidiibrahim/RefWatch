//
//  OpenAIAssistantService.swift
//  RefWatchiOS
//

import Foundation

final class OpenAIAssistantService: AssistantProviding {
    private let apiKey: String
    private let model: String
    private let systemPrompt: String

    init(apiKey: String, model: String = "gpt-4o-mini", systemPrompt: String = "You are RefWatch's helpful football referee assistant on iOS.") {
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
    }

    static func fromBundleIfAvailable() -> OpenAIAssistantService? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String, !key.isEmpty else { return nil }
        return OpenAIAssistantService(apiKey: key)
    }

    func streamResponse(for messages: [ChatMessage]) -> AsyncStream<String> {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        // Map chat messages to OpenAI schema
        var payload: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": Self.encodeMessages(system: systemPrompt, chat: messages)
        ]

        let req = Self.makeRequest(url: url, apiKey: apiKey, json: payload)

        return AsyncStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        continuation.finish()
                        return
                    }
                    for try await line in bytes.lines {
                        // SSE: lines prefixed with "data: "
                        guard line.hasPrefix("data: ") else { continue }
                        let dataStr = String(line.dropFirst("data: ".count))
                        if dataStr == "[DONE]" {
                            break
                        }
                        // Parse JSON chunk
                        if let chunkData = dataStr.data(using: .utf8) {
                            if let text = Self.parseDelta(from: chunkData) {
                                continuation.yield(text)
                            }
                        }
                    }
                } catch {
                    // Silently finish on errors for now
                }
                continuation.finish()
            }
        }
    }

    private static func makeRequest(url: URL, apiKey: String, json: [String: Any]) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.httpBody = try? JSONSerialization.data(withJSONObject: json)
        return req
    }

    private static func encodeMessages(system: String, chat: [ChatMessage]) -> [[String: String]] {
        var result: [[String: String]] = [["role": "system", "content": system]]
        for m in chat {
            result.append([
                "role": m.role == .user ? "user" : "assistant",
                "content": m.text
            ])
        }
        return result
    }

    private struct ChatStreamChunk: Decodable {
        struct Choice: Decodable { let delta: Delta? }
        struct Delta: Decodable { let content: String? }
        let choices: [Choice]
    }

    private static func parseDelta(from data: Data) -> String? {
        guard let chunk = try? JSONDecoder().decode(ChatStreamChunk.self, from: data) else { return nil }
        return chunk.choices.first?.delta?.content
    }
}

