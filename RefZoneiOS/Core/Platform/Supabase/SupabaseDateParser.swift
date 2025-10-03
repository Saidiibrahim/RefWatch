import Foundation

enum SupabaseDateParser {
  static func parse(
    _ value: String,
    isoWithFraction: ISO8601DateFormatter,
    isoWithoutFraction: ISO8601DateFormatter
  ) -> Date? {
    if let date = isoWithFraction.date(from: value) ?? isoWithoutFraction.date(from: value) {
      return date
    }

    let normalized = normalizePostgresTimestamp(value)
    return isoWithFraction.date(from: normalized) ?? isoWithoutFraction.date(from: normalized)
  }

  static func normalizePostgresTimestamp(_ value: String) -> String {
    var result = value.trimmingCharacters(in: .whitespacesAndNewlines)

    if let spaceIndex = result.firstIndex(of: " ") {
      result.replaceSubrange(spaceIndex...spaceIndex, with: "T")
    }

    guard let tzIndex = result.lastIndex(where: { $0 == "+" || $0 == "-" }) else {
      return result
    }

    let prefix = String(result[..<tzIndex])
    let suffix = String(result[tzIndex...])

    if suffix.contains(":") {
      return prefix + suffix
    }

    if suffix.count == 3 {
      return prefix + suffix + ":00"
    }

    if suffix.count == 5 {
      let hour = suffix.prefix(3)
      let minutes = suffix.suffix(2)
      return prefix + hour + ":" + minutes
    }

    return prefix + suffix
  }
}

enum SupabaseJSONDecoderFactory {
  private static let isoWithFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let isoWithoutFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)

      if let date = SupabaseDateParser.parse(
        value,
        isoWithFraction: isoWithFraction,
        isoWithoutFraction: isoWithoutFraction
      ) {
        return date
      }

      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Cannot decode date from: \(value)"
      )
    }
    return decoder
  }
}
