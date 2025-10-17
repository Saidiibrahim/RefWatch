#if os(iOS)
import Foundation
import HealthKit
import RefWorkoutCore

@available(iOS 17.0, *)
@MainActor
final class IOSHealthKitWorkoutAuthorizationManager: WorkoutAuthorizationManaging {
  private let healthStore: HKHealthStore
  private let shareTypes: Set<HKSampleType>
  private let readTypes: Set<HKObjectType>
  private let requiredReadTypes: [WorkoutAuthorizationMetric: HKQuantityType]
  private let optionalReadTypes: [WorkoutAuthorizationMetric: HKQuantityType]
  private var lastPromptedAt: Date?

  init(healthStore: HKHealthStore = HKHealthStore()) {
    self.healthStore = healthStore

    var share: Set<HKSampleType> = [HKObjectType.workoutType()]
    var read: Set<HKObjectType> = [HKObjectType.workoutType()]
    var requiredReads: [WorkoutAuthorizationMetric: HKQuantityType] = [:]
    var optionalReads: [WorkoutAuthorizationMetric: HKQuantityType] = [:]

    if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
      share.insert(distance)
      read.insert(distance)
      requiredReads[.distance] = distance
    }
    if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
      read.insert(heartRate)
      requiredReads[.heartRate] = heartRate
    }
    if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
      share.insert(energy)
      read.insert(energy)
      requiredReads[.activeEnergy] = energy
    }
    if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
      read.insert(vo2)
      optionalReads[.vo2Max] = vo2
    }

    shareTypes = share
    readTypes = read
    requiredReadTypes = requiredReads
    optionalReadTypes = optionalReads
  }

  func authorizationStatus() async -> WorkoutAuthorizationStatus {
    guard HKHealthStore.isHealthDataAvailable() else {
      return WorkoutAuthorizationStatus(state: .denied, lastPromptedAt: lastPromptedAt)
    }

    let workoutType = HKObjectType.workoutType()
    let shareStatus = healthStore.authorizationStatus(for: workoutType)

    switch shareStatus {
    case .notDetermined:
      return WorkoutAuthorizationStatus(state: .notDetermined, lastPromptedAt: lastPromptedAt)
    case .sharingDenied:
      return WorkoutAuthorizationStatus(state: .denied, lastPromptedAt: lastPromptedAt)
    case .sharingAuthorized:
      let deniedRequired = deniedRequiredMetrics()
      let deniedOptional = deniedOptionalMetrics()
      let state: WorkoutAuthorizationStatus.State = deniedRequired.isEmpty ? .authorized : .limited
      return WorkoutAuthorizationStatus(
        state: state,
        lastPromptedAt: lastPromptedAt,
        deniedMetrics: deniedRequired.union(deniedOptional)
      )
    @unknown default:
      return WorkoutAuthorizationStatus(state: .denied, lastPromptedAt: lastPromptedAt)
    }
  }

  func requestAuthorization() async throws -> WorkoutAuthorizationStatus {
    guard HKHealthStore.isHealthDataAvailable() else {
      throw WorkoutAuthorizationError.healthDataUnavailable
    }

    return try await withCheckedThrowingContinuation { continuation in
      healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, error in
        Task { @MainActor in
          if let error {
            continuation.resume(throwing: error)
            return
          }
          guard success else {
            continuation.resume(throwing: WorkoutAuthorizationError.requestFailed)
            return
          }
          self?.lastPromptedAt = Date()
          let status = await self?.authorizationStatus() ?? WorkoutAuthorizationStatus(state: .denied)
          continuation.resume(returning: status)
        }
      }
    }
  }

  private func deniedRequiredMetrics() -> Set<WorkoutAuthorizationMetric> {
    Set(requiredReadTypes.compactMap { metric, quantityType in
      let status = healthStore.authorizationStatus(for: quantityType)
      switch status {
      case .sharingAuthorized:
        return nil
      case .sharingDenied, .notDetermined:
        return metric
      @unknown default:
        return metric
      }
    })
  }

  private func deniedOptionalMetrics() -> Set<WorkoutAuthorizationMetric> {
    Set(optionalReadTypes.compactMap { metric, quantityType in
      let status = healthStore.authorizationStatus(for: quantityType)
      switch status {
      case .sharingAuthorized, .notDetermined:
        return nil
      case .sharingDenied:
        return metric
      @unknown default:
        return metric
      }
    })
  }
}
#endif
