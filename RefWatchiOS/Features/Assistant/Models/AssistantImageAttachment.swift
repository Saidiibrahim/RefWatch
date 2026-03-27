//
//  AssistantImageAttachment.swift
//  RefWatchiOS
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct AssistantImageAttachment: Identifiable, Hashable, Codable {
  enum Detail: String, Codable {
    case auto
    case low
    case high
    case original
  }

  let id: UUID
  let filename: String
  let mediaType: String
  let jpegData: Data
  let detail: Detail
  let pixelWidth: Int
  let pixelHeight: Int

  var dataURL: String {
    "data:\(self.mediaType);base64,\(self.jpegData.base64EncodedString())"
  }

  var byteCount: Int {
    self.jpegData.count
  }

  var data: Data {
    self.jpegData
  }

  var uiImage: UIImage? {
    UIImage(data: self.jpegData)
  }

  nonisolated init(
    id: UUID = UUID(),
    filename: String,
    mediaType: String = "image/jpeg",
    jpegData: Data,
    detail: Detail = .auto,
    pixelWidth: Int,
    pixelHeight: Int)
  {
    self.id = id
    self.filename = filename
    self.mediaType = mediaType
    self.jpegData = jpegData
    self.detail = detail
    self.pixelWidth = pixelWidth
    self.pixelHeight = pixelHeight
  }
}

enum AssistantImageAttachmentError: LocalizedError, Equatable {
  case unreadableImage
  case failedToEncode
  case tooLarge(maxBytes: Int)

  var errorDescription: String? {
    switch self {
    case .unreadableImage:
      return "That image could not be loaded."
    case .failedToEncode:
      return "That image could not be prepared for upload."
    case let .tooLarge(maxBytes):
      let maxMB = Double(maxBytes) / 1_000_000
      return "The selected image is too large to send. Choose one under \(String(format: "%.0f", maxMB)) MB."
    }
  }
}

enum AssistantImageAttachmentBuilder {
  nonisolated static let maxBytes = 8_000_000
  nonisolated static let maxDimension = 2_048
  nonisolated static let compressionQuality = 0.82

  nonisolated static func prepare(
    from data: Data,
    filename: String = "assistant-image.jpg",
    detail: AssistantImageAttachment.Detail = .auto) throws -> AssistantImageAttachment
  {
    let sourceOptions: CFDictionary = [
      kCGImageSourceShouldCache: false
    ] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
      throw AssistantImageAttachmentError.unreadableImage
    }
    let thumbnailOptions: CFDictionary = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: self.maxDimension
    ] as CFDictionary
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
      throw AssistantImageAttachmentError.unreadableImage
    }

    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      mutableData,
      UTType.jpeg.identifier as CFString,
      1,
      nil)
    else {
      throw AssistantImageAttachmentError.failedToEncode
    }

    let destinationOptions: CFDictionary = [
      kCGImageDestinationLossyCompressionQuality: self.compressionQuality
    ] as CFDictionary
    CGImageDestinationAddImage(destination, image, destinationOptions)

    guard CGImageDestinationFinalize(destination) else {
      throw AssistantImageAttachmentError.failedToEncode
    }

    let jpegData = Data(referencing: mutableData)
    guard jpegData.count <= self.maxBytes else {
      throw AssistantImageAttachmentError.tooLarge(maxBytes: self.maxBytes)
    }

    return AssistantImageAttachment(
      filename: filename,
      jpegData: jpegData,
      detail: detail,
      pixelWidth: image.width,
      pixelHeight: image.height)
  }
}
