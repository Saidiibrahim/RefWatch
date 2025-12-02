import Foundation

@MainActor
public protocol WorkoutSessionTracking {
  func startSession(configuration: WorkoutSessionConfiguration) async throws -> WorkoutSession
  func pauseSession(id: UUID) async throws
  func resumeSession(id: UUID) async throws
  func endSession(id: UUID, at date: Date) async throws -> WorkoutSession
  func recordEvent(_ event: WorkoutEvent, sessionId: UUID) async
  func liveMetricsStream() -> AsyncStream<WorkoutLiveMetrics>
}

#if canImport(Combine)
import Combine

@MainActor
public extension WorkoutSessionTracking {
  func liveMetricsPublisher() -> AnyPublisher<WorkoutLiveMetrics, Never> {
    LiveMetricsPublisher(streamFactory: { self.liveMetricsStream() })
      .eraseToAnyPublisher()
  }
}

private struct LiveMetricsPublisher<Element: Sendable>: Publisher {
  typealias Output = Element
  typealias Failure = Never

  let streamFactory: () -> AsyncStream<Element>

  func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    let stream = streamFactory()
    let subscription = LiveMetricsSubscription(subscriber: subscriber, stream: stream)
    subscriber.receive(subscription: subscription)
  }
}

private final class LiveMetricsSubscription<S: Subscriber, Element: Sendable>: Subscription where S.Input == Element, S.Failure == Never {
  private var subscriber: S?
  private var task: Task<Void, Never>?
  private var stream: AsyncStream<Element>?

  init(subscriber: S, stream: AsyncStream<Element>) {
    self.subscriber = subscriber
    self.stream = stream
  }

  func request(_ demand: Subscribers.Demand) {
    guard demand > .none, task == nil else { return }
    guard let stream = stream else { return }
    task = Task {
      guard let subscriber = self.subscriber else { return }
      for await metrics in stream {
        if Task.isCancelled { break }
        _ = subscriber.receive(metrics)
      }
      if !Task.isCancelled {
        subscriber.receive(completion: .finished)
      }
      self.cleanup()
    }
  }

  func cancel() {
    task?.cancel()
    cleanup()
  }

  private func cleanup() {
    task = nil
    subscriber = nil
    stream = nil
  }
}
#endif
