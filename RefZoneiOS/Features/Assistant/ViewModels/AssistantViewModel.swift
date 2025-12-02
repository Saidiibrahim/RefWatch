//
//  AssistantViewModel.swift
//  RefZoneiOS
//

import Foundation
import Combine

@MainActor
final class AssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""

    private let service: AssistantProviding
    private var streamingTask: Task<Void, Never>?

    init(service: AssistantProviding) {
        self.service = service
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(ChatMessage(role: .user, text: text))

        let assistant = ChatMessage(role: .assistant, text: "")
        messages.append(assistant)
        let index = messages.count - 1

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            for await chunk in service.streamResponse(for: messages) {
                await MainActor.run {
                    self.messages[index].text += chunk
                }
            }
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
    }
}
