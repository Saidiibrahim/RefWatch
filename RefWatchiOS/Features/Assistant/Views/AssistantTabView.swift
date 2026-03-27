//
//  AssistantTabView.swift
//  RefWatchiOS
//

import Foundation
import Observation
import PhotosUI
import UIKit
import SwiftUI

struct AssistantTabView: View {
  @EnvironmentObject private var authController: SupabaseAuthController
  @State private var usingStub = false
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var selectedPhotoLoadID = 0
  @State private var viewModel: AssistantViewModel

  init() {
    if let service = OpenAIAssistantService.fromBundleIfAvailable() {
      _viewModel = State(initialValue: AssistantViewModel(service: service))
      _usingStub = State(initialValue: false)
    } else {
      _viewModel = State(initialValue: AssistantViewModel(service: StubAssistantService()))
      _usingStub = State(initialValue: true)
    }
  }

  var body: some View {
    if self.authController.isSignedIn {
      NavigationStack {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
              if self.usingStub {
                HStack(spacing: 8) {
                  Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                    .padding(6)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                  Text("Assistant proxy unavailable — using demo replies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                  Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 6)
              }

              ForEach(self.viewModel.messages) { message in
                self.messageView(message)
                  .id(message.id)
              }
            }
            .padding(.horizontal)
            .padding(.top, 8)
          }
          .onChange(of: self.viewModel.messages.last?.id) { _, id in
            guard let id else { return }
            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
          }
        }
        .navigationTitle("Assistant")
        .safeAreaInset(edge: .bottom) {
          VStack(spacing: 8) {
            if self.showSuggestions {
              self.suggestionsRow
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if self.viewModel.isPreparingAttachment
              || self.viewModel.draftAttachment != nil
              || self.viewModel.attachmentErrorMessage != nil
              || self.viewModel.transportError != nil
            {
              self.draftAttachmentStack
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            self.modernInputBar
          }
          .padding(.top, self.showSuggestions ? 6 : 0)
          .background(.bar)
          .overlay(Divider(), alignment: .top)
        }
        .task(id: self.selectedPhotoLoadID) {
          guard self.selectedPhotoLoadID > 0, let item = self.selectedPhotoItem else { return }
          let data = try? await item.loadTransferable(type: Data.self)
          await self.viewModel.attachImageData(data)
          self.selectedPhotoItem = nil
        }
      }
    } else {
      NavigationStack {
        SignedOutFeaturePlaceholder(
          description: "Sign in to use RefWatch Assistant and sync conversations across your devices.")
          .navigationTitle("Assistant")
      }
    }
  }

  private func messageView(_ msg: ChatMessage) -> some View {
    HStack(alignment: .top) {
      if msg.role == .assistant {
        self.messageBubble(msg, foreground: .primary, background: Color(.secondarySystemBackground))
        Spacer(minLength: 24)
      } else {
        Spacer(minLength: 24)
        self.messageBubble(msg, foreground: .white, background: Color.accentColor)
      }
    }
  }

  private func messageBubble(_ msg: ChatMessage, foreground: Color, background: Color) -> some View {
    VStack(alignment: .leading, spacing: msg.attachment != nil && !msg.trimmedText.isEmpty ? 8 : 0) {
      if let attachment = msg.attachment {
        self.messageAttachmentView(attachment, maxWidth: 230)
      }

      if !msg.text.isEmpty {
        if let attributed = try? AttributedString(markdown: msg.text) {
          Text(attributed)
        } else {
          Text(msg.text)
        }
      }
    }
    .padding(10)
    .foregroundStyle(foreground)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // Modern bottom input bar with plus, pill text field, and conditional send/stop control.
  private var modernInputBar: some View {
    @Bindable var viewModel = self.viewModel

    return HStack(spacing: 10) {
      PhotosPicker(selection: self.photoSelectionBinding, matching: .images, photoLibrary: .shared()) {
        Circle()
          .fill(Color(.systemGray5))
          .frame(width: 34, height: 34)
          .overlay(Image(systemName: "plus").foregroundStyle(.primary))
      }
      .disabled(self.viewModel.isPreparingAttachment)
      .accessibilityLabel("Attach image")

      HStack(spacing: 8) {
        TextField("Ask anything", text: self.$viewModel.input, axis: .vertical)
          .textFieldStyle(.plain)
        if self.viewModel.isStreaming {
          Button(action: self.viewModel.stopStreaming) {
            Image(systemName: "stop.circle.fill")
              .font(.system(size: 20, weight: .semibold))
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(.secondary)
              .frame(width: 32, height: 32)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Stop generating")
          .transition(.opacity.combined(with: .scale))
          .buttonStyle(PressBounceStyle())
        } else if self.viewModel.canSend {
          Button(action: self.viewModel.send) {
            Image(systemName: "arrow.up.circle.fill")
              .font(.system(size: 20, weight: .semibold))
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(Color.accentColor)
              .frame(width: 32, height: 32)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Send")
          .transition(.opacity.combined(with: .scale))
          .buttonStyle(PressBounceStyle())
        } else if self.viewModel.isPreparingAttachment {
          ProgressView()
            .frame(width: 32, height: 32)
        } else {
          Button(action: self.viewModel.send) {
            Image(systemName: "arrow.up.circle.fill")
              .font(.system(size: 20, weight: .semibold))
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(self.viewModel.canSend ? Color.accentColor : .secondary)
              .frame(width: 32, height: 32)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Send")
          .disabled(self.viewModel.canSend == false)
          .buttonStyle(PressBounceStyle())
        }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .background(Color(.secondarySystemBackground))
      .clipShape(Capsule())
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  private var photoSelectionBinding: Binding<PhotosPickerItem?> {
    Binding(
      get: { self.selectedPhotoItem },
      set: { newValue in
        self.selectedPhotoItem = newValue
        if newValue != nil {
          self.selectedPhotoLoadID += 1
        }
      })
  }

  // Horizontal suggestions like chips
  private var suggestionsRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(Self.suggestions) { s in
          Button {
            self.viewModel.input = s.prompt
            self.viewModel.send()
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(s.title).font(.headline)
              if let sub = s.subtitle { Text(sub).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(PressBounceStyle())
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 2)
    }
  }

  // Suggestion visibility: show on empty history and when not typing
  private var showSuggestions: Bool {
    self.viewModel.messages.isEmpty
      && self.viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && self.viewModel.draftAttachment == nil
      && !self.viewModel.isPreparingAttachment
  }

  private var draftAttachmentStack: some View {
    VStack(spacing: 8) {
      if self.viewModel.isPreparingAttachment {
        HStack(spacing: 10) {
          ProgressView()
          Text("Preparing image...")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.horizontal)
      }

      if let attachment = self.viewModel.draftAttachment {
        HStack(spacing: 12) {
          self.attachmentPreview(for: attachment)

          VStack(alignment: .leading, spacing: 3) {
            Text("Image attached")
              .font(.subheadline.weight(.semibold))
            Text(Self.formatByteCount(attachment.data.count))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 8)

          Button {
            self.viewModel.removeDraftAttachment()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.title3)
              .foregroundStyle(.secondary)
          }
          .accessibilityLabel("Remove attached image")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
      }

      if let error = self.viewModel.attachmentErrorMessage {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
          Text(error)
            .font(.footnote)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
        }
        .padding(.horizontal)
      }

      if let error = self.viewModel.transportError {
        HStack(spacing: 8) {
          Image(systemName: "wifi.exclamationmark")
            .foregroundStyle(.red)
          Text(error)
            .font(.footnote)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
        }
        .padding(.horizontal)
      }
    }
  }

  private func attachmentPreview(for attachment: ChatMessage.ImageAttachment) -> some View {
    Group {
      if let image = UIImage(data: attachment.data) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          Color(.systemGray5)
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(width: 54, height: 54)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func messageAttachmentView(_ attachment: ChatMessage.ImageAttachment, maxWidth: CGFloat) -> some View {
    Group {
      if let image = UIImage(data: attachment.data) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: maxWidth, maxHeight: 280)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      } else {
        ZStack {
          Color(.systemGray5)
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
        }
        .frame(width: maxWidth, height: maxWidth * 0.75)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
    }
  }

  private static func formatByteCount(_ count: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(count))
  }

  private struct Suggestion: Identifiable {
    let id = UUID(); let title: String; let subtitle: String?; let prompt: String
  }

  private static let suggestions: [Suggestion] = [
    .init(
      title: "Clarify a rule",
      subtitle: "Offside or handball?",
      prompt: "Explain the offside rule with recent clarifications. Give examples."),
    .init(
      title: "Manage dissent",
      subtitle: "What’s a good phrase?",
      prompt: "Suggest calm, authoritative phrasing to manage dissent from players."),
    .init(
      title: "Track stoppage time",
      subtitle: "Best practice",
      prompt: "What are best practices to track and announce stoppage time?"),
  ]
}

// Reusable small press bounce for buttons
private struct PressBounceStyle: ButtonStyle {
  var scale: CGFloat = 0.94
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? self.scale : 1.0)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

#if DEBUG
#Preview {
  AssistantTabView()
    .environmentObject(SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
}
#endif
