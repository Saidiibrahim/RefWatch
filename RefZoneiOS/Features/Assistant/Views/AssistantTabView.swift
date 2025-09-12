//
//  AssistantTabView.swift
//  RefZoneiOS
//

import SwiftUI
import Foundation

struct AssistantTabView: View {
    @State private var usingStub = false
    @State private var showSpeakInfo = false
    @State private var showAttachInfo = false
    @StateObject private var viewModel: AssistantViewModel

    init() {
        if let svc = OpenAIAssistantService.fromBundleIfAvailable() {
            _viewModel = StateObject(wrappedValue: AssistantViewModel(service: svc))
            _usingStub = State(initialValue: false)
        } else {
            let stub = StubAssistantService()
            _viewModel = StateObject(wrappedValue: AssistantViewModel(service: stub))
            _usingStub = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if usingStub {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                            .padding(6).background(Color.orange).clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("OpenAI key missing — using demo replies.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                messageView(message)
                                    .id(message.id)
                            }

                            if viewModel.messages.isEmpty {
                                suggestionsRow
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onChange(of: viewModel.messages.last?.id) { id in
                        guard let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }

                modernInputBar
            }
            .navigationTitle("Assistant")
            .alert("Speak Not Set Up", isPresented: $showSpeakInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Realtime voice will come later. Use text for now.")
            }
            .alert("Coming Soon", isPresented: $showAttachInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Attachments and tools are not available yet.")
            }
        }
    }

    private func messageView(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if msg.role == .assistant {
                VStack(alignment: .leading) {
                    if let attributed = try? AttributedString(markdown: msg.text) {
                        Text(attributed)
                    } else {
                        Text(msg.text)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 24)
            } else {
                Spacer(minLength: 24)
                Text(msg.text)
                    .padding(10)
                    .foregroundStyle(.white)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // Modern bottom input bar with plus, pill text field, and audio button
    private var modernInputBar: some View {
        HStack(spacing: 10) {
            Button { showAttachInfo = true } label: {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "plus").foregroundStyle(.primary))
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                TextField("Ask anything", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.plain)
                Button { showSpeakInfo = true } label: {
                    Image(systemName: "mic")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .clipShape(Capsule())

            Button(action: viewModel.send) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "waveform").foregroundStyle(.white))
            }
            .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    // Horizontal suggestions like chips
    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Self.suggestions) { s in
                    Button { viewModel.input = s.prompt; viewModel.send() } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).font(.headline)
                            if let sub = s.subtitle { Text(sub).font(.caption).foregroundStyle(.secondary) }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private struct Suggestion: Identifiable { let id = UUID(); let title: String; let subtitle: String?; let prompt: String }
    private static let suggestions: [Suggestion] = [
        .init(title: "Clarify a rule", subtitle: "Offside or handball?", prompt: "Explain the offside rule with recent clarifications. Give examples."),
        .init(title: "Manage dissent", subtitle: "What’s a good phrase?", prompt: "Suggest calm, authoritative phrasing to manage dissent from players."),
        .init(title: "Track stoppage time", subtitle: "Best practice", prompt: "What are best practices to track and announce stoppage time?")
    ]
}

#Preview { AssistantTabView() }
