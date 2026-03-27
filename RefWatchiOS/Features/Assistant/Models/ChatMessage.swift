//
//  ChatMessage.swift
//  RefWatchiOS
//

import Foundation

struct ChatMessage: Identifiable, Hashable {
  typealias ImageAttachment = AssistantImageAttachment

  enum Role: String, Codable {
    case user
    case assistant
  }

  enum ContentPart: Hashable, Codable {
    case text(String)
    case image(AssistantImageAttachment)

    var textValue: String? {
      if case let .text(text) = self {
        return text
      }
      return nil
    }

    var imageValue: AssistantImageAttachment? {
      if case let .image(attachment) = self {
        return attachment
      }
      return nil
    }
  }

  let id: UUID
  let role: Role
  var content: [ContentPart]
  let date: Date

  var text: String {
    self.content
      .compactMap(\.textValue)
      .joined(separator: "\n")
  }

  var imageAttachment: AssistantImageAttachment? {
    self.content.lazy.compactMap(\.imageValue).first
  }

  var attachment: AssistantImageAttachment? {
    self.imageAttachment
  }

  var trimmedText: String {
    self.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var hasRenderableContent: Bool {
    self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      || self.imageAttachment != nil
  }

  init(
    id: UUID = UUID(),
    role: Role,
    content: [ContentPart],
    date: Date = Date())
  {
    self.id = id
    self.role = role
    self.content = content
    self.date = date
  }

  init(
    id: UUID = UUID(),
    role: Role,
    text: String,
    imageAttachment: AssistantImageAttachment? = nil,
    date: Date = Date())
  {
    var content: [ContentPart] = []
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedText.isEmpty == false {
      content.append(.text(trimmedText))
    }
    if let imageAttachment {
      content.append(.image(imageAttachment))
    }

    self.init(id: id, role: role, content: content, date: date)
  }

  mutating func appendText(_ chunk: String) {
    guard chunk.isEmpty == false else { return }

    if let index = self.content.lastIndex(where: {
      if case .text = $0 {
        return true
      }
      return false
    }) {
      if case let .text(existing) = self.content[index] {
        self.content[index] = .text(existing + chunk)
      }
    } else {
      self.content.append(.text(chunk))
    }
  }
}
