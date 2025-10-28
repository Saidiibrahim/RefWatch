---
task_id: 01
plan_id: PLAN_healthkit_authorization_fixes
plan_file: ../../plans/PLAN_healthkit_authorization_fixes.md
title: Fix requestAuthorization() to rebuild selection items after authorization grant
phase: Phase 1 - Critical Bug Fixes
---

# TASK_01: Fix Authorization Refresh Bug

## Objective

Fix the bug where the authorization card persists in the workout carousel even after the user successfully grants HealthKit permissions on their iPhone.

## Problem

Currently, `WorkoutModeViewModel.requestAuthorization()` (lines 696-724) updates the `authorization` property but never calls `rebuildSelectionItems()`. This means:
- The authorization card remains visible in the carousel
- Workout options remain gated/disabled
- User must manually navigate away and back to see updates

Compare with `refreshAuthorization()` (lines 691-694) which correctly calls `rebuildSelectionItems()` after updating authorization state.

## Solution

### Primary Fix
Add `self.rebuildSelectionItems()` call immediately after `self.authorization = status` in the success path of `requestAuthorization()`.

**Location**: `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift:702`

**Current Code** (lines 696-724):
```swift
func requestAuthorization() {
  Task { @MainActor in
    self.isPerformingAction = true
    defer { self.isPerformingAction = false }
    do {
      let status = try await self.services.authorizationManager.requestAuthorization()
      self.authorization = status
      // Missing rebuild call here!
      self.errorMessage = nil
      self.recoveryAction = nil
    } catch let authError as WorkoutAuthorizationError {
      // ... error handling
    }
  }
}
```

**Updated Code**:
```swift
func requestAuthorization() {
  Task { @MainActor in
    self.isPerformingAction = true
    defer { self.isPerformingAction = false }
    do {
      let status = try await self.services.authorizationManager.requestAuthorization()
      self.authorization = status
      self.rebuildSelectionItems()  // ← ADD THIS LINE
      self.errorMessage = nil
      self.recoveryAction = nil
    } catch let authError as WorkoutAuthorizationError {
      // ... error handling
    }
  }
}
```

### Optional Enhancement: Delayed Refresh

Since authorization happens on the paired iPhone, there may be a timing delay between the request completing and HealthKit state updating. Consider adding a delayed refresh:

```swift
func requestAuthorization() {
  Task { @MainActor in
    self.isPerformingAction = true
    defer { self.isPerformingAction = false }
    do {
      let status = try await self.services.authorizationManager.requestAuthorization()
      self.authorization = status
      self.rebuildSelectionItems()
      self.errorMessage = nil
      self.recoveryAction = nil

      // Optional: Refresh again after short delay to catch async updates
      Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        await self?.refreshAuthorization()
      }
    } catch let authError as WorkoutAuthorizationError {
      // ... error handling
    }
  }
}
```

## Testing

### Manual Test
1. Reset HealthKit permissions for RefWatch in iPhone Settings → Privacy & Security → Health
2. Open RefWatch on Apple Watch
3. Verify authorization card appears in carousel
4. Tap "Grant Access" button
5. Approve permissions on iPhone in Health app
6. **Expected**: Authorization card immediately disappears from carousel, workout cards become accessible
7. **Bug if**: Card persists until user navigates away from workout screen

### Code Review Checklist
- [ ] `rebuildSelectionItems()` is called after authorization status update
- [ ] Call is inside the success `do` block, not in error paths
- [ ] Call happens on `@MainActor` (already guaranteed by Task annotation)
- [ ] No duplicate rebuild calls that could cause unnecessary UI updates

## Files Modified

- `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`
  - Line ~702: Add `self.rebuildSelectionItems()` call
  - Optional: Lines ~706-711: Add delayed refresh task

## Dependencies

None - this is a standalone fix.

## Estimated Effort

**15 minutes** (simple one-line addition + testing)

## Notes

- This fix mirrors the pattern already used in `refreshAuthorization()` (line 693)
- The delayed refresh is optional but recommended to handle async iPhone approval timing
- Consider using the `lastPromptedAt` property from `HealthKitWorkoutAuthorizationManager` in future work to throttle repeated authorization requests
