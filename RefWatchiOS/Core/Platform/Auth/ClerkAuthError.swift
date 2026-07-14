import Foundation

enum ClerkAuthError: LocalizedError, Equatable {
  case signedOut
  case tokenUnavailable
  case sdk(message: String)

  var errorDescription: String? {
    switch self {
    case .signedOut:
      "Sign in to continue."
    case .tokenUnavailable:
      "Your session could not be authenticated. Sign in again."
    case let .sdk(message):
      message
    }
  }

  static func map(_ error: Error) -> ClerkAuthError {
    if let error = error as? ClerkAuthError { return error }
    return .sdk(message: error.localizedDescription)
  }
}
