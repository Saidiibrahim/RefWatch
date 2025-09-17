#if os(watchOS)
import Foundation
import HealthKit
import RefWorkoutCore

@MainActor
final class HealthKitWorkoutAuthorizationManager: WorkoutAuthorizationManaging, @unchecked Sendable {
  private let healthStore: HKHealthStore
  private let shareTypes: Set<HKSampleType>
  private let readTypes: Set<HKObjectType>
  private var lastPromptedAt: Date?

  init(healthStore: HKHealthStore = HKHealthStore()) {
    self.healthStore = healthStore

    var share: Set<HKSampleType> = [HKObjectType.workoutType()]
    var read: Set<HKObjectType> = [HKObjectType.workoutType()]

    if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
      share.insert(distance)
      read.insert(distance)
    }
    if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
      read.insert(heartRate)
    }
    if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
      share.insert(energy)
      read.insert(energy)
    }
    if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
      read.insert(vo2)
    }

    shareTypes = share
    readTypes = read
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
      let limited = hasLimitedReadAccess()
      return WorkoutAuthorizationStatus(state: limited ? .limited : .authorized, lastPromptedAt: lastPromptedAt)
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

  private func hasLimitedReadAccess() -> Bool {
    readTypes.contains { objectType in
      guard let quantityType = objectType as? HKQuantityType else { return false }
      let status = healthStore.authorizationStatus(for: quantityType)
      switch status {
      case .sharingAuthorized:
        return false
      case .sharingDenied:
        return true
      case .notDetermined:
        return false
      @unknown default:
        return true
      }
    }
  }
}

#endif
