---
task_id: 02
plan_id: PLAN_healthkit_authorization_fixes
plan_file: ../../plans/PLAN_healthkit_authorization_fixes.md
title: Add pre-flight authorization check in beginStartingSession()
phase: Phase 1 - Critical Bug Fixes
---

# TASK_02: Add Just-In-Time Authorization Guard

## Objective

Prevent users from attempting to start workouts when they haven't granted required HealthKit permissions, providing clear, actionable error messages instead of cryptic HealthKit collection failures.

## Problem

Currently, `WorkoutModeViewModel.beginStartingSession()` (lines 639-668) does not check authorization status before attempting to start a HealthKit workout session. This leads to:

1. User taps a workout card without having granted permissions
2. ViewModel calls `services.sessionTracker.startSession()`
3. HealthKit fails internally during collection setup
4. User sees generic "Failed to start workout: collection begin failed" error
5. No clear guidance on how to fix (user doesn't know it's a permissions issue)

## Solution

Add a pre-flight authorization check at the start of `beginStartingSession()` that validates permissions before attempting session start.

**Location**: `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift:639-668`

**Current Code**:
```swift
private func beginStartingSession(selectionItem: WorkoutSelectionItem, configuration: WorkoutSessionConfiguration) {
  Task { @MainActor in
    self.isPerformingAction = true
    defer { self.isPerformingAction = false }
    self.cancelPendingDwell()
    self.presentationState = .starting(selectionItem)
    self.lastCommittedSelectionID = selectionItem.id
    do {
      let session = try await self.services.sessionTracker.startSession(configuration: configuration)
      // ... success path
    } catch {
      // ... error handling
    }
  }
}
```

**Updated Code**:
```swift
private func beginStartingSession(selectionItem: WorkoutSelectionItem, configuration: WorkoutSessionConfiguration) {
  Task { @MainActor in
    self.cancelPendingDwell()

    guard authorization.isAuthorized else {
      self.presentationState = .error(selectionItem, .authorizationDenied)
      self.errorMessage = WorkoutError.authorizationDenied.errorDescription
      self.recoveryAction = WorkoutError.authorizationDenied.recoveryAction
      return
    }

    self.isPerformingAction = true
    defer { self.isPerformingAction = false }
    self.presentationState = .starting(selectionItem)
    self.lastCommittedSelectionID = selectionItem.id
    do {
      let session = try await self.services.sessionTracker.startSession(configuration: configuration)
      // ... success path (unchanged)
    } catch {
      // ... error handling (unchanged)
    }
  }
}
```

## Implementation Details

### Authorization Property

Calling `cancelPendingDwell()` before the guard ensures the carousel never stays in a locked dwell state even when we bail early.

The guard uses `authorization.isAuthorized` which is defined in `WorkoutAuthorizationStatus`:
- Returns `true` when `state == .authorized`
- Returns `false` for `.notDetermined`, `.denied`, or `.limited`

If we later need to allow "limited" states that still include all required metrics, we can swap to `!authorization.hasRequiredLimitations`. For now, the stricter `isAuthorized` path guarantees the session only starts when the watch has every capability we expect.

### Error Handling

Using `WorkoutError.authorizationDenied` provides:
- **Error Description**: "HealthKit access denied. Manage workout permissions on your paired iPhone."
- **Recovery Action**: "On your iPhone, open Settings > Health > Data Access & Devices > RefWatch to enable workout permissions."

These messages live in `WorkoutModeViewModel.swift:18-47` and are updated in TASK_03.

### Presentation State

Setting `presentationState = .error(selectionItem, .authorizationDenied)` ensures:
- `WorkoutSessionPreviewView` (or error view) can display the error
- User sees the specific workout they tried to start
- UI provides context for the authorization requirement

## Alternative Considerations

### Should we check for `hasRequiredLimitations` instead?

Currently using `isAuthorized` which checks for `.authorized` state. We could be more granular:

```swift
// More permissive - allow if required metrics are available
guard !authorization.hasRequiredLimitations else {
  self.presentationState = .error(selectionItem, .authorizationDenied)
  // ...
}
```

**Decision**: Use `isAuthorized` for now because:
- HealthKit authorization is all-or-nothing for workouts (need both read and write)
- `hasRequiredLimitations` already exists, so we can easily revisit if we decide to support limited states
- Simpler to reason about and test today

If we need more granular control in the future, we can refine this check.

### Should we show an alert instead of error state?

Current approach uses `presentationState = .error()` which likely shows an error view. Alternative would be to show an alert dialog that keeps the user on the preview screen.

**Decision**: Use error state for consistency with other error paths in `beginStartingSession()`. All errors (session start failures, collection failures, etc.) use this pattern.

## Testing

### Manual Test Cases

**Test Case 1: No Permissions**
1. Reset HealthKit permissions for RefWatch
2. Open RefWatch workout mode
3. Scroll past authorization card
4. Tap any workout (quick start, preset, or last completed)
5. **Expected**: Error view with "HealthKit access denied. Manage workout permissions on your paired iPhone." message and the updated recovery action
6. **Bug if**: Generic collection error or attempt to start session

**Test Case 2: Partial Permissions (if applicable)**
1. Grant some but not all HealthKit permissions
2. Attempt to start workout
3. **Expected**: Clear error about missing permissions
4. **Bug if**: Session starts then fails mid-workout

**Test Case 3: Full Permissions**
1. Grant all required HealthKit permissions
2. Tap workout card
3. **Expected**: Workout starts successfully (guard check passes)
4. **Bug if**: Authorization error shown despite having permissions

### Unit Test

Add to `WorkoutModeViewModelTests.swift`:

```swift
@MainActor
func testBeginStartingSession_blocksWhenNotAuthorized() async {
  // Given: ViewModel with unauthorized state
  let services = MockWorkoutServices()
  let appModeController = AppModeController()
  let viewModel = WorkoutModeViewModel(
    services: services,
    appModeController: appModeController
  )
  viewModel.authorization = WorkoutAuthorizationStatus(state: .notDetermined)

  let item = WorkoutSelectionItem(
    id: .quickStart(.outdoorRun),
    content: .quickStart(kind: .outdoorRun)
  )

  // When: User attempts to start workout
  viewModel.startSelection(for: item)

  // Wait for async task
  try? await Task.sleep(nanoseconds: 100_000_000)

  // Then: Presentation state is error with authorization denied
  if case .error(let errorItem, let error) = viewModel.presentationState {
    XCTAssertEqual(errorItem.id, item.id)
    XCTAssertEqual(error, .authorizationDenied)
  } else {
    XCTFail("Expected error presentation state, got \(viewModel.presentationState)")
  }

  XCTAssertNotNil(viewModel.errorMessage)
  XCTAssertNotNil(viewModel.recoveryAction)

  // And: Session tracker was never called
  XCTAssertEqual(services.sessionTracker.startSessionCallCount, 0)
}

@MainActor
func testBeginStartingSession_allowsWhenAuthorized() async {
  // Given: ViewModel with authorized state
  let services = MockWorkoutServices()
  let appModeController = AppModeController()
  let viewModel = WorkoutModeViewModel(
    services: services,
    appModeController: appModeController
  )
  viewModel.authorization = WorkoutAuthorizationStatus(state: .authorized)

  let item = WorkoutSelectionItem(
    id: .quickStart(.outdoorRun),
    content: .quickStart(kind: .outdoorRun)
  )

  // When: User attempts to start workout
  viewModel.startSelection(for: item)

  // Wait for async task
  try? await Task.sleep(nanoseconds: 100_000_000)

  // Then: Session start was attempted
  XCTAssertEqual(services.sessionTracker.startSessionCallCount, 1)

  // And: No authorization error
  if case .error(_, let error) = viewModel.presentationState {
    XCTAssertNotEqual(error, .authorizationDenied)
  }
}
```

## Files Modified

- `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`
  - Lines ~639-645: Add authorization guard at start of `beginStartingSession()`

## Dependencies

- Requires `WorkoutAuthorizationStatus.isAuthorized` property (already exists)
- Requires `WorkoutError.authorizationDenied` case (already defined at line 7)
- May require updates to `WorkoutSessionPreviewView` or error handling views to properly display authorization errors (verify separately)

## Estimated Effort

**30 minutes** (code change + unit tests + manual testing)

## Notes

- This guard should come **before** any side effects (setting `isPerformingAction`, changing `presentationState`, etc.) to avoid state inconsistencies
- The guard check is cheap (property read), so no performance concerns
- Consider adding similar guards to other critical operations (pause, resume, end session) in future work
- This fix prevents the symptom but doesn't proactively guide users - that's addressed in TASK_03 (better copy) and TASK_04 (onboarding flow)
