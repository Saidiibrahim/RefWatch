import Foundation

public struct WorkoutMetric: Hashable, Codable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case distance
    case duration
    case averagePace
    case averageSpeed
    case averageHeartRate
    case maximumHeartRate
    case calories
    case elevationGain
    case cadence
    case power
    case perceivedExertion
  }

  public enum Unit: String, Codable, Sendable {
    case meters
    case kilometers
    case seconds
    case minutes
    case minutesPerKilometer
    case kilometersPerHour
    case beatsPerMinute
    case kilocalories
    case metersClimbed
    case stepsPerMinute
    case watts
    case ratingOfPerceivedExertion

    public enum Category: Sendable {
      case length
      case duration
      case pace
      case speed
      case heartRate
      case energy
      case elevation
      case cadence
      case power
      case rating
    }

    public var category: Category {
      switch self {
      case .meters, .kilometers:
        return .length
      case .seconds, .minutes:
        return .duration
      case .minutesPerKilometer:
        return .pace
      case .kilometersPerHour:
        return .speed
      case .beatsPerMinute:
        return .heartRate
      case .kilocalories:
        return .energy
      case .metersClimbed:
        return .elevation
      case .stepsPerMinute:
        return .cadence
      case .watts:
        return .power
      case .ratingOfPerceivedExertion:
        return .rating
      }
    }
  }

  public let kind: Kind
  public var value: Double
  public var unit: Unit

  public init(kind: Kind, value: Double, unit: Unit) {
    self.kind = kind
    self.value = value
    self.unit = unit
  }

  public static func distance(_ measurement: Measurement<UnitLength>) -> WorkoutMetric {
    let unit: Unit = measurement.unit == .kilometers ? .kilometers : .meters
    let targetUnit: UnitLength = unit == .kilometers ? .kilometers : .meters
    let converted = measurement.converted(to: targetUnit)
    return WorkoutMetric(kind: .distance, value: converted.value, unit: unit)
  }

  public static func duration(_ measurement: Measurement<UnitDuration>) -> WorkoutMetric {
    let unit: Unit = measurement.unit == .minutes ? .minutes : .seconds
    let targetUnit: UnitDuration = unit == .minutes ? .minutes : .seconds
    let converted = measurement.converted(to: targetUnit)
    return WorkoutMetric(kind: .duration, value: converted.value, unit: unit)
  }

  public static func energy(_ measurement: Measurement<UnitEnergy>) -> WorkoutMetric {
    WorkoutMetric(kind: .calories, value: measurement.converted(to: .kilocalories).value, unit: .kilocalories)
  }

  public var lengthMeasurement: Measurement<UnitLength>? {
    switch unit {
    case .meters:
      return Measurement(value: value, unit: .meters)
    case .kilometers:
      return Measurement(value: value, unit: .kilometers)
    default:
      return nil
    }
  }

  public var durationMeasurement: Measurement<UnitDuration>? {
    switch unit {
    case .seconds:
      return Measurement(value: value, unit: .seconds)
    case .minutes:
      return Measurement(value: value, unit: .minutes)
    default:
      return nil
    }
  }

  public var energyMeasurement: Measurement<UnitEnergy>? {
    switch unit {
    case .kilocalories:
      return Measurement(value: value, unit: .kilocalories)
    default:
      return nil
    }
  }

  public var elevationMeasurement: Measurement<UnitLength>? {
    switch unit {
    case .metersClimbed:
      return Measurement(value: value, unit: .meters)
    default:
      return nil
    }
  }

  public func converted(to targetUnit: Unit) -> WorkoutMetric? {
    guard unit != targetUnit else { return self }
    guard unit.category == targetUnit.category else { return nil }

    switch unit.category {
    case .length:
      guard let source = lengthMeasurement else { return nil }
      let targetMeasurement: Measurement<UnitLength>
      switch targetUnit {
      case .meters:
        targetMeasurement = source.converted(to: .meters)
      case .kilometers:
        targetMeasurement = source.converted(to: .kilometers)
      default:
        return nil
      }
      return WorkoutMetric(kind: kind, value: targetMeasurement.value, unit: targetUnit)

    case .duration:
      guard let source = durationMeasurement else { return nil }
      let targetMeasurement: Measurement<UnitDuration>
      switch targetUnit {
      case .seconds:
        targetMeasurement = source.converted(to: .seconds)
      case .minutes:
        targetMeasurement = source.converted(to: .minutes)
      default:
        return nil
      }
      return WorkoutMetric(kind: kind, value: targetMeasurement.value, unit: targetUnit)

    case .energy:
      guard let source = energyMeasurement else { return nil }
      let targetMeasurement = source.converted(to: .kilocalories)
      return WorkoutMetric(kind: kind, value: targetMeasurement.value, unit: .kilocalories)

    case .elevation:
      guard let source = elevationMeasurement else { return nil }
      switch targetUnit {
      case .metersClimbed:
        let targetMeasurement = source.converted(to: .meters)
        return WorkoutMetric(kind: kind, value: targetMeasurement.value, unit: .metersClimbed)
      default:
        return nil
      }

    case .pace, .speed, .heartRate, .cadence, .power, .rating:
      // These categories currently support a single canonical unit aligned with AU preferences.
      return unit == targetUnit ? self : nil
    }
  }
}
