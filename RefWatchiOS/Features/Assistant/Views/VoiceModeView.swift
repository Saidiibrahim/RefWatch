//
//  VoiceModeView.swift
//  RefWatchiOS
//
//  Full-screen voice capture UI with large waveform and timer.
//  Tap anywhere to finish and return the recognized text.
//

import SwiftUI

struct VoiceModeView: View {
    var onFinish: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var transcript: String = ""
    @State private var power: Double = 0
    @State private var startedAt = Date()

    var body: some View {
        ZStack {
            RadialGradient(colors: [.black, Color(white: 0.08)], center: .center, startRadius: 40, endRadius: 600)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                TimelineView(.periodic(from: startedAt, by: 0.1)) { _ in
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 220 + power * 60, height: 220 + power * 60)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 3)
                                .blur(radius: 0.5)
                        )
                        .overlay(
                            VStack(spacing: 8) {
                                Text(elapsedString)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.white)
                                Text("Listening…")
                                    .foregroundStyle(.secondary)
                            }
                        )
                        .animation(.easeOut(duration: 0.12), value: power)
                }

                Text(transcript)
                    .foregroundStyle(.white)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .frame(maxHeight: 160)
                Spacer()
                Text("Tap anywhere to finish")
                    .foregroundStyle(.secondary)
                Spacer().frame(height: 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear(perform: start)
        .onDisappear { SpeechTranscriber.shared.stop() }
    }

    private var elapsedString: String {
        let seconds = Int(Date().timeIntervalSince(startedAt))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func start() {
        startedAt = Date()
        SpeechTranscriber.shared.requestAuthorization { ok in
            guard ok else { finish() ; return }
            SpeechTranscriber.shared.startTranscribing(onPartial: { part in
                self.transcript = part
            }, onFinal: { final in
                self.transcript = final
            }, onError: { _ in
                // Ignore errors visually; allow user to tap to close
            }, onPower: { p in
                self.power = p
            })
        }
    }

    private func finish() {
        SpeechTranscriber.shared.stop()
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
        if !text.isEmpty { onFinish(text) }
    }
}

#Preview {
    VoiceModeView { _ in }
}

