import Combine
import RefWatchCore

/// Vendor-neutral observable authentication state used by iOS stores and coordinators.
@MainActor
protocol AuthStateProviding: AuthenticationProviding {
  var statePublisher: AnyPublisher<AuthState, Never> { get }
  /// False while a persisted vendor session may still be restoring. Consumers must not
  /// treat `.signedOut` as an explicit logout until this becomes true.
  var isAuthStateResolved: Bool { get }
  var authStateResolvedPublisher: AnyPublisher<Bool, Never> { get }
}

extension AuthStateProviding {
  var isAuthStateResolved: Bool { true }
  var authStateResolvedPublisher: AnyPublisher<Bool, Never> {
    Just(true).eraseToAnyPublisher()
  }
}

/// Supplies a short-lived session token suitable for the backend Authorization header.
@MainActor
protocol SessionTokenProviding {
  func sessionToken() async throws -> String
}
