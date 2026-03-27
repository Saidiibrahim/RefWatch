//
//  AssistantViewModel.swift
//  RefWatchiOS
//

import Foundation
import Observation

@Observable
final class AssistantViewModel {
  var messages: [ChatMessage] = []
  var input: String = ""
  var draftAttachment: AssistantImageAttachment?
  var attachmentError: String?
  var transportError: String?
  private(set) var isPreparingAttachment = false
  private(set) var isStreaming = false

  private let service: AssistantProviding
  private var activeStreamID: UUID?
  private var activeResponse: AssistantResponseStream?

  init(service: AssistantProviding) {
    self.service = service
  }

  var canSend: Bool {
    self.isStreaming == false
      && (
        self.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      || self.draftAttachment != nil
      )
  }

  var attachmentErrorMessage: String? {
    self.attachmentError
  }

  func prepareAttachment(from data: Data, filename: String = "assistant-image.jpg") {
    self.attachmentError = nil
    self.transportError = nil
    self.isPreparingAttachment = true

    Task { @MainActor [weak self] in
      guard let self else { return }

      do {
        let attachment = try await Task.detached(priority: .userInitiated) {
          try AssistantImageAttachmentBuilder.prepare(from: data, filename: filename)
        }.value
        self.draftAttachment = attachment
      } catch {
        self.draftAttachment = nil
        self.attachmentError = error.localizedDescription
      }
      self.isPreparingAttachment = false
    }
  }

  func attachImageData(_ data: Data?, filename: String = "assistant-image.jpg") async {
    self.attachmentError = nil
    self.transportError = nil
    self.isPreparingAttachment = true

    defer {
      self.isPreparingAttachment = false
    }

    guard let data else {
      self.draftAttachment = nil
      self.attachmentError = AssistantImageAttachmentError.unreadableImage.localizedDescription
      return
    }

    do {
      let attachment = try await Task.detached(priority: .userInitiated) {
        try AssistantImageAttachmentBuilder.prepare(from: data, filename: filename)
      }.value
      self.draftAttachment = attachment
    } catch {
      self.draftAttachment = nil
      self.attachmentError = error.localizedDescription
    }
  }

  func removeDraftAttachment() {
    self.draftAttachment = nil
    self.attachmentError = nil
  }

  func send() {
    guard self.canSend else { return }

    let pendingUserMessage = ChatMessage(
      role: .user,
      text: self.input,
      imageAttachment: self.draftAttachment)
    let outgoingMessages = self.messages + [pendingUserMessage]

    self.transportError = nil
    self.isStreaming = true

    let token = UUID()
    self.activeStreamID = token
    Task { @MainActor [weak self, token] in
      guard let self else { return }

      do {
        let response = try await self.service.streamResponse(for: outgoingMessages)
        guard self.activeStreamID == token else {
          response.cancel()
          return
        }
        self.activeResponse = response

        self.messages.append(pendingUserMessage)
        self.messages.append(ChatMessage(role: .assistant, content: []))
        let assistantIndex = self.messages.count - 1

        self.input = ""
        self.draftAttachment = nil
        self.attachmentError = nil

        do {
          for try await chunk in response.stream {
            guard self.activeStreamID == token else { break }
            self.messages[assistantIndex].appendText(chunk)
          }
        } catch is CancellationError {
          // Keep any streamed partial text in place when the user stops generation.
        } catch {
          guard self.activeStreamID == token else { return }
          if self.messages[assistantIndex].text.isEmpty {
            self.messages[assistantIndex].appendText(error.localizedDescription)
          } else {
            self.transportError = error.localizedDescription
          }
        }
      } catch is CancellationError {
        // No-op: a newer send replaced this one before the request started.
      } catch {
        guard self.activeStreamID == token else { return }
        self.transportError = error.localizedDescription
      }

      guard self.activeStreamID == token else { return }
      self.isStreaming = false
      self.activeStreamID = nil
      self.activeResponse = nil
    }
  }

  func stopStreaming() {
    self.activeResponse?.cancel()
    self.activeResponse = nil
    self.activeStreamID = nil
    self.isStreaming = false
  }
}
