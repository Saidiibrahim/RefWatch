#if os(watchOS)
import Foundation
import HealthKit
import RefWorkoutCore

@MainActor
final class HealthKitWorkoutAuthorizationManager: WorkoutAuthorizationManaging {
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

    self.shareTypes = share
    self.readTypes = read
    self.requiredReadTypes = requiredReads
    self.optionalReadTypes = optionalReads
  }

  func authorizationStatus() async -> WorkoutAuthorizationStatus {
    guard HKHealthStore.isHealthDataAvailable() else {
      return WorkoutAuthorizationStatus(state: .denied, lastPromptedAt: self.lastPromptedAt)
    }

    let workoutType = HKObjectType.workoutType()
    let shareStatus = self.healthStore.authorizationStatus(for: workoutType)

    switch shareStatus {
    case .notDetermined:
      return WorkoutAuthorizationStatus(state: .notDetermined, lastPromptedAt: self.lastPromptedAt)
    case .sharingDenied:
      return WorkoutAuthorizationStatus(state: .denied, lastPromptedAt: self.lastPromptedAt)
    case .sharingAuthorized:
      // Compute denied metrics asynchronously to properly check read-only permissions
      let (deniedRequired, deniedOptional) = await computeDeniedMetrics()
      let state: WorkoutAuthorizationStatus.State = deniedRequired.isEmpty ? .authorized : .limited
      return WorkoutAuthorizationStatus(
        state: state,
        lastPromptedAt: self.lastPromptedAt,
        deniedMetrics: deniedRequired.union(deniedOptional))
    @unknown default:
      return WorkoutAuthorizationStatus(state: .denied, lastPromptedAt: self.lastPromptedAt)
    }
  }

  func requestAuthorization() async throws -> WorkoutAuthorizationStatus {
    guard HKHealthStore.isHealthDataAvailable() else {
      throw WorkoutAuthorizationError.healthDataUnavailable
    }

    return try await withCheckedThrowingContinuation { continuation in
      self.healthStore
        .requestAuthorization(toShare: self.shareTypes, read: self.readTypes) { [weak self] success, error in
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

  /// Computes which metrics are denied for both required and optional types.
  /// Uses proper HealthKit APIs: authorizationStatus(for:) for share types,
  /// and getRequestStatusForAuthorization for read-only types.
  private func computeDeniedMetrics() async -> (Set<WorkoutAuthorizationMetric>, Set<WorkoutAuthorizationMetric>) {
    // Helper to check if a read-only type still needs authorization
    // Note: authorizationStatus(for:) only works for share types, so for read-only
    // types we must use getRequestStatusForAuthorization to check read permission
    func shouldRequestReadAuthorization(for type: HKObjectType) async -> Bool {
      await withCheckedContinuation { continuation in
        self.healthStore.getRequestStatusForAuthorization(toShare: [], read: [type]) { status, error in
          // If status is .shouldRequest, we still need authorization (denied)
          // If status is .unnecessary, authorization was already granted
          continuation.resume(returning: status == .shouldRequest && error == nil)
        }
      }
    }

    // For types we request to SHARE, we can check share authorization status directly
    func deniedFromShareTypes(_ mapping: [WorkoutAuthorizationMetric: HKQuantityType])
    -> Set<WorkoutAuthorizationMetric> {
      Set(mapping.compactMap { metric, quantityType in
        // Only check share status for types we're requesting write access to
        guard self.shareTypes.contains(quantityType) else {
          return nil
        }
        let status = self.healthStore.authorizationStatus(for: quantityType)
        switch status {
        case .sharingAuthorized:
          return nil // Authorized, not denied
        case .sharingDenied, .notDetermined:
          return metric // Denied or not yet determined
        @unknown default:
          return metric
        }
      })
    }

    // For READ-ONLY types (not in shareTypes), check read authorization status
    func deniedFromReadOnlyTypes(_ mapping: [WorkoutAuthorizationMetric: HKQuantityType]) async
    -> Set<WorkoutAuthorizationMetric> {
      let readOnlyTypes = mapping.filter { !self.shareTypes.contains($0.value) }

      // Check all read-only types concurrently
      let results = await withTaskGroup(of: (WorkoutAuthorizationMetric, Bool).self) { group -> [(
        WorkoutAuthorizationMetric,
        Bool)] in
        for (metric, quantityType) in readOnlyTypes {
          group.addTask {
            let needsRequest = await shouldRequestReadAuthorization(for: quantityType)
            return (metric, needsRequest)
          }
        }
        var collected: [(WorkoutAuthorizationMetric, Bool)] = []
        for await result in group {
          collected.append(result)
        }
        return collected
      }

      // Return metrics that still need authorization (denied)
      return Set(results.compactMap { metric, needsRequest in
        needsRequest ? metric : nil
      })
    }

    // Compute denied metrics for both required and optional, handling share vs read-only separately
    let deniedRequiredShare = deniedFromShareTypes(requiredReadTypes)
    let deniedOptionalShare = deniedFromShareTypes(optionalReadTypes)
    let deniedRequiredRead = await deniedFromReadOnlyTypes(requiredReadTypes)
    let deniedOptionalRead = await deniedFromReadOnlyTypes(optionalReadTypes)

    // Combine share and read-only denied metrics
    let deniedRequired = deniedRequiredShare.union(deniedRequiredRead)
    let deniedOptional = deniedOptionalShare.union(deniedOptionalRead)

    return (deniedRequired, deniedOptional)
  }
}

#endif
