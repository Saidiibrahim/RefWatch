import Foundation

enum BackendAPIError: LocalizedError, Equatable {
  case invalidRequest
  case invalidResponse
  case localAuthenticationUnavailable(message: String?)
  case unauthenticated(message: String?)
  case forbidden(message: String?)
  case validation(message: String?, details: Data?)
  case server(status: Int, message: String?)
  case encoding(message: String)
  case decoding(message: String)
  case transport(message: String)

  var errorDescription: String? {
    switch self {
    case .invalidRequest:
      "The backend request could not be created."
    case .invalidResponse:
      "The backend returned an invalid response."
    case let .localAuthenticationUnavailable(message):
      message ?? "The current session token is unavailable."
    case let .unauthenticated(message):
      message ?? "Sign in again to continue."
    case let .forbidden(message):
      message ?? "You do not have permission to perform this action."
    case let .validation(message, _):
      message ?? "The backend rejected the request."
    case let .server(status, message):
      message ?? "The backend request failed with HTTP \(status)."
    case let .encoding(message), let .decoding(message), let .transport(message):
      message
    }
  }
}
