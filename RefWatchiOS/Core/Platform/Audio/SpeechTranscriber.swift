//
//  SpeechTranscriber.swift
//  RefWatchiOS
//
//  Lightweight wrapper around SFSpeechRecognizer + AVAudioEngine
//  to capture a short voice note and stream partial text.
//

import AVFoundation
import Foundation
import SwiftUI
#if canImport(Speech)
import Speech
#endif

final class SpeechTranscriber {
  static let shared = SpeechTranscriber()

  #if canImport(Speech)
  private let recognizer = SFSpeechRecognizer()
  private let audioEngine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  #endif

  private init() {}

  /// Requests microphone + speech permissions.
  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    #if canImport(Speech)
    SFSpeechRecognizer.requestAuthorization { status in
      let speechOK = (status == .authorized)
      let deliver: (Bool) -> Void = { micOK in
        DispatchQueue.main.async { completion(speechOK && micOK) }
      }

      if #available(iOS 17.0, *) {
        Task {
          let granted = await AVAudioApplication.requestRecordPermission()
          deliver(granted)
        }
      } else {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          deliver(granted)
        }
      }
    }
    #else
    completion(false)
    #endif
  }

  /// Starts streaming speech recognition, emitting partial and final text.
  func startTranscribing(
    onPartial: @escaping (String) -> Void,
    onFinal: @escaping (String) -> Void,
    onError: @escaping (Error) -> Void,
    onPower: ((Double) -> Void)? = nil)
  {
    #if canImport(Speech)
    self.stop() // reset anything lingering

    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      onError(error)
      return
    }

    self.request = SFSpeechAudioBufferRecognitionRequest()
    self.request?.shouldReportPartialResults = true

    let inputNode = self.audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
      self.request?.append(buffer)
      if let onPower {
        let p = Self.estimatePower(from: buffer)
        DispatchQueue.main.async { onPower(p) }
      }
    }

    self.audioEngine.prepare()
    do { try self.audioEngine.start() } catch { onError(error); return }

    guard let recognizer else { return }
    self.task = recognizer.recognitionTask(with: self.request!) { result, error in
      if let error { onError(error); return }
      guard let result else { return }
      let text = result.bestTranscription.formattedString
      if result.isFinal {
        onFinal(text)
      } else {
        onPartial(text)
      }
    }
    #else
    // Fallback: Not available on this platform
    onError(
      NSError(
        domain: "SpeechTranscriber",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Speech framework unavailable."]))
    #endif
  }

  /// Stops recognition and audio capture.
  func stop() {
    #if canImport(Speech)
    self.task?.cancel()
    self.task = nil
    self.request?.endAudio()
    self.request = nil
    if self.audioEngine.isRunning { self.audioEngine.stop() }
    self.audioEngine.inputNode.removeTap(onBus: 0)
    try? AVAudioSession.sharedInstance().setActive(false)
    #endif
  }

  #if canImport(Speech)
  private static func estimatePower(from buffer: AVAudioPCMBuffer) -> Double {
    guard let channel = buffer.floatChannelData?.pointee else { return 0 }
    let frameLength = Int(buffer.frameLength)
    if frameLength == 0 { return 0 }
    var sum: Float = 0
    var ptr = channel
    for _ in 0..<frameLength {
      sum += abs(ptr.pointee); ptr = ptr.advanced(by: 1)
    }
    let mean = sum / Float(frameLength)
    // Normalize roughly into 0...1 range; tune factor as needed
    let normalized = min(max(Double(mean) * 6.0, 0), 1)
    return normalized
  }
  #endif
}
