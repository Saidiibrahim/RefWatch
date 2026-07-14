import Foundation

enum BackendHTTPMethod: String {
  case delete = "DELETE"
  case get = "GET"
  case post = "POST"
  case put = "PUT"
}

struct BackendHTTPStream {
  let response: HTTPURLResponse
  let bytes: AsyncThrowingStream<Data, Error>
}

protocol BackendHTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
  func stream(for request: URLRequest) async throws -> BackendHTTPStream
}

final class URLSessionBackendHTTPTransport: BackendHTTPTransport {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await session.data(for: request)
  }

  func stream(for request: URLRequest) async throws -> BackendHTTPStream {
    let (source, response) = try await session.bytes(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw BackendAPIError.invalidResponse
    }
    let stream = AsyncThrowingStream<Data, Error> { continuation in
      let task = Task {
        do {
          var buffer = Data()
          buffer.reserveCapacity(4096)
          for try await byte in source {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= 4096 {
              continuation.yield(buffer)
              buffer.removeAll(keepingCapacity: true)
            }
          }
          if buffer.isEmpty == false { continuation.yield(buffer) }
          continuation.finish()
        } catch is CancellationError {
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
    return BackendHTTPStream(response: httpResponse, bytes: stream)
  }
}

final class BackendAPIClient {
  private struct ErrorEnvelope: Decodable {
    let message: String?
    let error: String?
  }

  private let baseURL: URL
  private let tokenProvider: any SessionTokenProviding
  private let transport: any BackendHTTPTransport
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    baseURL: URL,
    tokenProvider: any SessionTokenProviding,
    transport: any BackendHTTPTransport = URLSessionBackendHTTPTransport(),
    encoder: JSONEncoder = BackendAPIClient.makeEncoder(),
    decoder: JSONDecoder = BackendAPIClient.makeDecoder())
  {
    self.baseURL = baseURL
    self.tokenProvider = tokenProvider
    self.transport = transport
    self.encoder = encoder
    self.decoder = decoder
  }

  func send<Response: Decodable>(
    _ responseType: Response.Type = Response.self,
    path: String,
    method: BackendHTTPMethod = .get,
    queryItems: [URLQueryItem] = [],
    body: (any Encodable)? = nil,
    idempotencyKey: String? = nil) async throws -> Response
  {
    let request = try await makeRequest(
      path: path,
      method: method,
      queryItems: queryItems,
      body: body,
      idempotencyKey: idempotencyKey,
      accept: "application/json")
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await transport.data(for: request)
    } catch let error as BackendAPIError {
      throw error
    } catch {
      throw BackendAPIError.transport(message: error.localizedDescription)
    }
    try validate(response: response, data: data)
    do {
      return try decoder.decode(Response.self, from: data)
    } catch {
      throw BackendAPIError.decoding(message: error.localizedDescription)
    }
  }

  func sendWithoutResponse(
    path: String,
    method: BackendHTTPMethod,
    queryItems: [URLQueryItem] = [],
    body: (any Encodable)? = nil,
    idempotencyKey: String? = nil) async throws
  {
    let request = try await makeRequest(
      path: path,
      method: method,
      queryItems: queryItems,
      body: body,
      idempotencyKey: idempotencyKey,
      accept: "application/json")
    do {
      let (data, response) = try await transport.data(for: request)
      try validate(response: response, data: data)
    } catch let error as BackendAPIError {
      throw error
    } catch {
      throw BackendAPIError.transport(message: error.localizedDescription)
    }
  }

  func stream(
    path: String,
    method: BackendHTTPMethod = .post,
    queryItems: [URLQueryItem] = [],
    body: (any Encodable)? = nil,
    accept: String = "text/event-stream") async throws -> BackendHTTPStream
  {
    let request = try await makeRequest(
      path: path,
      method: method,
      queryItems: queryItems,
      body: body,
      idempotencyKey: nil,
      accept: accept)
    do {
      let stream = try await transport.stream(for: request)
      guard (200..<300).contains(stream.response.statusCode) else {
        throw mapHTTPError(status: stream.response.statusCode, data: nil)
      }
      return stream
    } catch let error as BackendAPIError {
      throw error
    } catch {
      throw BackendAPIError.transport(message: error.localizedDescription)
    }
  }

  private func makeRequest(
    path: String,
    method: BackendHTTPMethod,
    queryItems: [URLQueryItem],
    body: (any Encodable)?,
    idempotencyKey: String?,
    accept: String) async throws -> URLRequest
  {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw BackendAPIError.invalidRequest
    }
    let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
    let requestPath = path.hasPrefix("/") ? path : "/\(path)"
    components.path = basePath + requestPath
    components.queryItems = queryItems.isEmpty ? nil : queryItems
    guard let url = components.url else { throw BackendAPIError.invalidRequest }

    let token: String
    do {
      token = try await tokenProvider.sessionToken()
    } catch let error as ClerkAuthError {
      throw BackendAPIError.localAuthenticationUnavailable(message: error.errorDescription)
    } catch {
      throw BackendAPIError.localAuthenticationUnavailable(message: error.localizedDescription)
    }

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(accept, forHTTPHeaderField: "Accept")
    if let idempotencyKey, idempotencyKey.isEmpty == false {
      request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
    }
    if let body {
      do {
        request.httpBody = try encoder.encode(BackendAnyEncodable(body))
      } catch {
        throw BackendAPIError.encoding(message: error.localizedDescription)
      }
    }
    return request
  }

  private func validate(response: URLResponse, data: Data) throws {
    guard let response = response as? HTTPURLResponse else {
      throw BackendAPIError.invalidResponse
    }
    guard (200..<300).contains(response.statusCode) else {
      throw mapHTTPError(status: response.statusCode, data: data)
    }
  }

  private func mapHTTPError(status: Int, data: Data?) -> BackendAPIError {
    let envelope = data.flatMap { try? decoder.decode(ErrorEnvelope.self, from: $0) }
    let message = envelope?.message ?? envelope?.error
    switch status {
    case 401: return .unauthenticated(message: message)
    case 403: return .forbidden(message: message)
    case 400, 409, 422: return .validation(message: message, details: data)
    default: return .server(status: status, message: message)
    }
  }

  static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      if let date = fractional.date(from: value) ?? standard.date(from: value) { return date }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
    }
    return decoder
  }
}

private struct BackendAnyEncodable: Encodable {
  private let encodeValue: (Encoder) throws -> Void

  init(_ value: any Encodable) {
    encodeValue = { encoder in
      try value.encode(to: encoder)
    }
  }

  func encode(to encoder: Encoder) throws {
    try encodeValue(encoder)
  }
}
