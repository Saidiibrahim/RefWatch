//
//  AssistantTabView.swift
//  RefZoneiOS
//

import SwiftUI
import Foundation

struct AssistantTabView: View {
    @EnvironmentObject private var authController: SupabaseAuthController
    @State private var usingStub = false
    @State private var showSpeakInfo = false
    @State private var showAttachInfo = false
    @StateObject private var viewModel: AssistantViewModel
    @State private var isRecordingInline = false
    @State private var inlineStart: Date? = nil
    @State private var inlinePower: Double = 0
    @State private var inlineDebounceItem: DispatchWorkItem? = nil
    @State private var showVoiceMode = false

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
        if authController.isSignedIn {
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if usingStub {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                                        .padding(6)
                                        .background(Color.orange)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Text("OpenAI key missing — using demo replies.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 6)
                            }

                            ForEach(viewModel.messages) { message in
                                messageView(message)
                                    .id(message.id)
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
                .navigationTitle("Assistant")
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        if showSuggestions {
                            suggestionsRow
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        modernInputBar
                    }
                    .padding(.top, showSuggestions ? 6 : 0)
                    .background(.bar)
                    .overlay(Divider(), alignment: .top)
                }
                .sheet(isPresented: $showVoiceMode) {
                    VoiceModeView { finalText in
                        let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        viewModel.input = trimmed
                        viewModel.send()
                    }
                }
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
        } else {
            NavigationStack {
                SignedOutFeaturePlaceholder(
                    description: "Sign in to use RefZone Assistant and sync conversations across your devices."
                )
                .navigationTitle("Assistant")
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

    // Modern bottom input bar with plus, pill text field, and conditional mic/send + voice mode button
    private var modernInputBar: some View {
        HStack(spacing: 10) {
            Button { showAttachInfo = true } label: {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "plus").foregroundStyle(.primary))
            }

            HStack(spacing: 8) {
                if let start = inlineStart, isRecordingInline {
                    InlineRecordingIndicator(start: start, power: inlinePower)
                        .transition(.opacity)
                }
                TextField("Ask anything", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.plain)
                // Trailing control switches between mic (no input) and send (has input)
                if hasInput {
                    Button(action: viewModel.send) {
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
                } else {
                    Button(action: toggleInlineRecording) {
                        Image(systemName: isRecordingInline ? "mic.fill" : "mic")
                            .foregroundStyle(isRecordingInline ? .red : .secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Record voice for input")
                    .transition(.opacity.combined(with: .scale))
                    .buttonStyle(PressBounceStyle())
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())

            // Big black button enters voice mode (distinct from inline mic)
            Button(action: { showVoiceMode = true }) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "waveform").foregroundStyle(.white))
            }
            .accessibilityLabel("Voice Mode")
            .buttonStyle(PressBounceStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // Horizontal suggestions like chips
    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Self.suggestions) { s in
                    Button {
                        viewModel.input = s.prompt
                        viewModel.send()
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
        viewModel.messages.isEmpty && viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasInput: Bool {
        !viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Toggle inline speech recognition and stream transcript into the input field.
    private func toggleInlineRecording() {
        if isRecordingInline {
            SpeechTranscriber.shared.stop()
            isRecordingInline = false
            inlineStart = nil
            inlinePower = 0
            return
        }

        SpeechTranscriber.shared.requestAuthorization { granted in
            guard granted else { self.showSpeakInfo = true; return }
            self.isRecordingInline = true
            let base = self.viewModel.input
            self.inlineStart = Date()
            SpeechTranscriber.shared.startTranscribing(onPartial: { partial in
                // Debounce partial updates to reduce cursor jumpiness
                self.inlineDebounceItem?.cancel()
                let item = DispatchWorkItem {
                    let spacer = base.isEmpty ? "" : " "
                    self.viewModel.input = base + spacer + partial
                }
                self.inlineDebounceItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: item)
            }, onFinal: { finalText in
                DispatchQueue.main.async {
                    let spacer = base.isEmpty ? "" : " "
                    self.viewModel.input = base + spacer + finalText
                    self.isRecordingInline = false
                    self.inlineStart = nil
                }
                SpeechTranscriber.shared.stop()
            }, onError: { _ in
                DispatchQueue.main.async {
                    self.isRecordingInline = false
                    self.inlineStart = nil
                }
            }, onPower: { p in
                self.inlinePower = p
            })
        }
    }

    private struct Suggestion: Identifiable { let id = UUID(); let title: String; let subtitle: String?; let prompt: String }
    private static let suggestions: [Suggestion] = [
        .init(title: "Clarify a rule", subtitle: "Offside or handball?", prompt: "Explain the offside rule with recent clarifications. Give examples."),
        .init(title: "Manage dissent", subtitle: "What’s a good phrase?", prompt: "Suggest calm, authoritative phrasing to manage dissent from players."),
        .init(title: "Track stoppage time", subtitle: "Best practice", prompt: "What are best practices to track and announce stoppage time?")
    ]
}

// Reusable small press bounce for buttons
private struct PressBounceStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Small inline recording indicator that lives inside the input pill
private struct InlineRecordingIndicator: View {
    let start: Date
    let power: Double // 0...1

    var body: some View {
        TimelineView(.periodic(from: start, by: 0.5)) { _ in
            HStack(spacing: 6) {
                WaveBars(power: power)
                Text(Self.formatElapsed(since: start))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
        }
    }

    private static func formatElapsed(since: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(since)))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

private struct WaveBars: View {
    let power: Double // 0...1
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                let height = 6.0 + power * 10.0 + Double(i) * 2.0
                Capsule()
                    .fill(Color.secondary)
                    .frame(width: 3, height: height)
            }
        }
    }
}

#Preview { AssistantTabView() }
