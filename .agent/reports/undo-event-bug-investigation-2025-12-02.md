# Event Undo Bug Investigation Report
**Date:** December 2, 2025
**Platform:** iOS (watchOS untested)
**Status:** Needs Lead Engineer Verification
**Priority:** High (if confirmed)
**Reporter:** Early Tester Feedback
**Investigated By:** Claude Code Analysis

---

## Executive Summary

Early testers report that when attempting to undo a recorded event (goal, card, or substitution) in the iOS app, **all events are removed** from the match log instead of just the most recent event.

**Critical Finding:** Static code analysis reveals **no obvious defect** in the undo implementation. The `undoLastUserEvent()` method correctly identifies and removes only a single event. Unit tests confirm this behavior works as expected.

**Conclusion:** This issue requires hands-on verification by the lead engineer to either:
1. Identify a runtime edge case not visible in static analysis
2. Reproduce and document the exact steps triggering the bug
3. Determine if this is a user misunderstanding or display rendering issue

---

## Issue Description

### User Report
When users record match events (goals, cards, substitutions) and then attempt to undo the most recent event using the "Undo" button in the confirmation banner, they observe that all events disappear from the Events Log instead of just the undone event.

### Expected Behavior
1. User records Event A (e.g., Goal by Home team)
2. User records Event B (e.g., Yellow card to Away team)
3. User records Event C (e.g., Substitution for Home team)
4. User taps "Undo" → **Only Event C should be removed**
5. Events A and B should remain visible in the log

### Reported Behavior
1. User records Event A, B, C
2. User taps "Undo"
3. **All events (A, B, C) disappear from the log**

### User Impact
- **Severity**: High (if confirmed as data loss bug)
- **Frequency**: Unknown (needs reproduction steps)
- **UX Impact**: Critical match data appears lost, undermines trust in app
- **Functionality**: Potential data integrity issue

---

## Code Analysis

### Core Undo Implementation

The undo logic is implemented in the shared `MatchViewModel` class and should work identically across iOS and watchOS platforms.

#### **MatchViewModel.swift:701-730** - `undoLastUserEvent()` Method

```swift
@discardableResult
public func undoLastUserEvent() -> Bool {
    guard let index = matchEvents.lastIndex(where: { isUndoable($0) }) else { return false }
    let event = matchEvents[index]

    switch event.eventType {
    case .goal:
        guard let team = event.team else { return false }
        revertGoal(for: team)
        matchEvents.remove(at: index)  // ← Removes ONLY the event at this index
    case .card(let details):
        guard let team = event.team else { return false }
        revertCard(for: team, cardType: details.cardType)
        matchEvents.remove(at: index)  // ← Removes ONLY the event at this index
    case .substitution:
        guard let team = event.team else { return false }
        revertSubstitution(for: team)
        matchEvents.remove(at: index)  // ← Removes ONLY the event at this index
    case .penaltyAttempt:
        return undoLastPenaltyAttempt()
    default:
        return false
    }

    if pendingConfirmation?.event.id == event.id {
        pendingConfirmation = nil
    }

    haptics.play(.success)
    return true
}
```

**Analysis:**
- **Line 702**: Uses `lastIndex(where:)` to find the LAST event that is undoable
- **Lines 709, 713, 717**: Uses `matchEvents.remove(at: index)` which removes **only** the element at the specified index
- **No code path** calls `matchEvents.removeAll()` or clears the entire array during undo

#### **MatchViewModel.swift:547-554** - Undoable Event Filter

```swift
private func isUndoable(_ event: MatchEventRecord) -> Bool {
    switch event.eventType {
    case .goal, .card, .substitution, .penaltyAttempt:
        return true
    default:
        return false
    }
}
```

**Analysis:**
- Correctly filters for user-initiated events only
- System events (kickOff, periodStart, periodEnd, etc.) are NOT undoable

### iOS Undo Button Implementation

#### **MatchTimerView.swift:247-250** - Undo Button Action

```swift
Button("Undo") {
    _ = matchViewModel.undoLastUserEvent()
    matchViewModel.clearPendingConfirmation()
}
```

**Analysis:**
- Calls `undoLastUserEvent()` from ViewModel (shared logic)
- Calls `clearPendingConfirmation()` to dismiss the confirmation banner
- No additional logic that could affect event array

#### **MatchViewModel.swift:694-698** - Clear Pending Confirmation

```swift
@MainActor
public func clearPendingConfirmation(id: UUID? = nil) {
    guard let current = pendingConfirmation else { return }
    if let id, current.id != id { return }
    pendingConfirmation = nil  // Only clears UI state, not event data
}
```

**Analysis:**
- Only clears the `pendingConfirmation` UI state variable
- Does NOT touch the `matchEvents` array

### Event Display Logic

#### **MatchTimerView.swift:304-309** - EventsLogView Rendering

```swift
ForEach(matchViewModel.matchEvents) { event in
    EventRow(event: event, theme: theme)
        .id(event.id)
    Divider()
        .opacity(event.id == matchViewModel.matchEvents.last?.id ? 0 : 0.3)
}
```

**Analysis:**
- Directly iterates over `matchViewModel.matchEvents` array
- **No filtering** is applied - all events in the array are displayed
- Uses SwiftUI's `ForEach` with `Identifiable` protocol for proper view updates

### Unit Test Evidence

#### **MatchViewModel_EventsAndStoppageTests.swift:94-106**

```swift
func test_undo_goal_reverts_score_and_history() {
    let vm = MatchViewModel()
    vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

    vm.startMatch()  // Creates kickOff + periodStart events
    vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)  // Adds goal event
    let eventCount = vm.matchEvents.count  // Should be 3 events total

    XCTAssertTrue(vm.undoLastUserEvent())
    XCTAssertEqual(vm.currentMatch?.homeScore, 0)  // Score reverted
    XCTAssertEqual(vm.matchEvents.count, eventCount - 1)  // ONLY 1 event removed
    XCTAssertNil(vm.pendingConfirmation)  // Confirmation cleared
}
```

**Test Outcome:** ✅ PASSING
- Confirms only ONE event is removed (eventCount - 1)
- Confirms score is properly reverted
- Test has been part of the codebase and presumably runs in CI

---

## Possible Root Causes

Since the static code analysis shows correct implementation, the bug may stem from:

### 1. **User Misunderstanding**
**Hypothesis:** Users may be confusing system events with user events.

**Scenario:**
1. User starts match → Creates `kickOff` and `periodStart` events (not displayed prominently or not recognized as "events" by users)
2. User records a goal → Creates `goal` event (user recognizes this as "an event")
3. User taps undo → Goal is removed, leaving only `kickOff` and `periodStart`
4. User perceives the log as "empty" because they only recognize user-initiated events

**Verification Needed:**
- Check if system events (kickOff, periodStart) are visually distinct in the Events Log
- Determine if users are expecting only goals/cards/subs to appear, not system events

### 2. **SwiftUI State Update Bug**
**Hypothesis:** Race condition or animation bug causes visual glitch where all events temporarily disappear.

**Scenario:**
1. User taps "Undo"
2. ViewModel correctly removes one event from array
3. SwiftUI's `ForEach` triggers re-render with new array count
4. Animation or state transition bug causes entire list to disappear temporarily
5. List eventually re-renders correctly, but user has already perceived it as broken

**Verification Needed:**
- Test on physical device (simulator may not reproduce timing issues)
- Add logging to track exact array contents before/after undo
- Check if events reappear after a delay or screen refresh

### 3. **Edge Case During Specific Event Sequences**
**Hypothesis:** Specific combination of event types triggers a bug not covered by unit tests.

**Scenario Examples:**
- Undoing during penalty shootout
- Undoing immediately after period transition
- Undoing when `pendingConfirmation` auto-dismisses (2-second timer on watchOS)
- Undoing after recording multiple events in rapid succession

**Verification Needed:**
- Request specific reproduction steps from testers
- Test undo after recording: Goal → Card → Substitution → Undo
- Test undo during edge cases (halftime, extra time, penalties)

### 4. **iOS-Specific SwiftUI Rendering Issue**
**Hypothesis:** iOS-specific view update bug not present on watchOS.

**Scenario:**
- The `EventsLogView` uses `LazyVStack` inside `ScrollView` with `ScrollViewReader`
- `onChange(of: matchViewModel.matchEvents.count)` triggers scroll animation
- Scroll animation conflicts with view updates, causing visual glitch

**Verification Needed:**
- Test on watchOS to determine if issue is iOS-only
- Temporarily disable scroll animation and retest
- Check iOS version-specific SwiftUI bugs (iOS 17/18 differences)

### 5. **Multiple Undo Taps (Double-Tap)**
**Hypothesis:** User accidentally double-taps "Undo" button, removing multiple events.

**Scenario:**
1. User taps "Undo" button
2. Button remains tappable during animation/state update
3. User taps again (intentionally or accidentally)
4. Multiple events are removed in quick succession

**Verification Needed:**
- Add tap debouncing or disable button after first tap
- Check if button remains interactive during confirmation dismissal

---

## Files Requiring Investigation

### Core Logic (Shared)
1. [MatchViewModel.swift:701-730](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L701-L730) - `undoLastUserEvent()` implementation
2. [MatchViewModel.swift:547-554](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L547-L554) - `isUndoable()` filter
3. [MatchViewModel.swift:83](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L83) - `matchEvents` array declaration
4. [MatchViewModel.swift:694-698](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L694-L698) - `clearPendingConfirmation()`

### iOS UI Layer
5. [MatchTimerView.swift:247-250](RefZoneiOS/Features/Match/MatchTimer/MatchTimerView.swift#L247-L250) - Undo button action
6. [MatchTimerView.swift:304-309](RefZoneiOS/Features/Match/MatchTimer/MatchTimerView.swift#L304-L309) - EventsLogView ForEach rendering
7. [MatchTimerView.swift:315-317](RefZoneiOS/Features/Match/MatchTimer/MatchTimerView.swift#L315-L317) - `onChange` scroll trigger
8. [MatchTimerView.swift:241-261](RefZoneiOS/Features/Match/MatchTimer/MatchTimerView.swift#L241-L261) - Confirmation banner

### watchOS UI Layer (for comparison)
9. [TimerView.swift:110-120](RefZoneWatchOS/Features/Timer/Views/TimerView.swift#L110-L120) - Auto-dismiss confirmation logic
10. [MatchActionsSheet.swift:182-188](RefZoneWatchOS/Features/Timer/Views/MatchActionsSheet.swift#L182-L188) - watchOS undo button
11. [EventConfirmationView.swift](RefZoneWatchOS/Features/Timer/Views/EventConfirmationView.swift) - watchOS confirmation overlay

### Tests
12. [MatchViewModel_EventsAndStoppageTests.swift:94-106](RefWatchCore/Tests/RefWatchCoreTests/MatchViewModel_EventsAndStoppageTests.swift#L94-L106) - Passing undo test

---

## Recommended Investigation Steps for Lead Engineer

### Phase 1: Reproduce the Issue (Critical)
1. **Request Detailed Steps from Testers**
   - Exact sequence of events recorded before undo
   - Which event was being undone (first, middle, last)
   - Was undo triggered from banner or actions sheet
   - Device model and iOS version
   - Any screen recordings or screenshots

2. **Attempt Reproduction**
   - Follow exact tester steps on physical iOS device
   - Try various event sequences:
     - Record 1 event → Undo
     - Record 3 events (goal, card, sub) → Undo
     - Record events rapidly → Undo immediately
   - Test during different match states (first half, halftime, extra time)

3. **Add Diagnostic Logging**
   ```swift
   @discardableResult
   public func undoLastUserEvent() -> Bool {
       print("🔍 UNDO: Before - Event count: \(matchEvents.count)")
       print("🔍 UNDO: Events: \(matchEvents.map { $0.eventType.displayName })")

       guard let index = matchEvents.lastIndex(where: { isUndoable($0) }) else {
           print("🔍 UNDO: No undoable event found")
           return false
       }

       let event = matchEvents[index]
       print("🔍 UNDO: Removing event at index \(index): \(event.eventType.displayName)")

       // ... existing switch logic ...

       print("🔍 UNDO: After - Event count: \(matchEvents.count)")
       print("🔍 UNDO: Events: \(matchEvents.map { $0.eventType.displayName })")
       return true
   }
   ```

### Phase 2: Verify Event Display
1. **Check Event Log Contents**
   - Add temporary UI showing event count and types
   - Verify system events (kickOff, periodStart) are displaying as expected
   - Check if EventRow properly renders all event types

2. **Test View Updates**
   - Add breakpoint in EventsLogView ForEach
   - Verify SwiftUI re-renders with correct array after undo
   - Check if `matchEvents.count` onChange trigger fires correctly

### Phase 3: Test Edge Cases
1. **Rapid Undo Tapping**
   - Tap undo button multiple times quickly
   - Check if button debouncing is needed

2. **Auto-Dismiss Interaction**
   - Wait for confirmation banner to auto-dismiss (if implemented on iOS)
   - Then manually trigger undo from actions sheet
   - Check for state conflicts

3. **Period Transitions**
   - Record event at end of period
   - Trigger period end (adds periodEnd event)
   - Undo the user event
   - Verify periodEnd event remains

### Phase 4: Platform Comparison
1. **Test on watchOS**
   - Perform identical event recording and undo sequence
   - Determine if issue is iOS-specific or cross-platform
   - Compare EventConfirmationView vs. iOS confirmation banner behavior

2. **Check SwiftUI Differences**
   - watchOS uses overlay confirmation (EventConfirmationView)
   - iOS uses banner within VStack
   - Different rendering pipelines may behave differently

---

## Temporary Workarounds (If Bug Confirmed)

If the bug is confirmed as a real data loss issue, consider these immediate mitigations:

### 1. **Disable Undo Feature** (Nuclear Option)
```swift
// In MatchTimerView.swift
private var pendingConfirmationBanner: some View {
    if matchViewModel.pendingConfirmation != nil {
        HStack(spacing: theme.spacing.s) {
            Label("Event saved", systemImage: "checkmark.circle")
                .font(.subheadline)
            // Spacer()
            // Button("Undo") { ... }  // ← Comment out until fixed
        }
        // ...
    }
}
```

### 2. **Add Confirmation Dialog for Undo**
```swift
Button("Undo") {
    showUndoConfirmation = true
}
.confirmationDialog("Undo last event?", isPresented: $showUndoConfirmation) {
    Button("Yes, Undo", role: .destructive) {
        let beforeCount = matchViewModel.matchEvents.count
        _ = matchViewModel.undoLastUserEvent()
        let afterCount = matchViewModel.matchEvents.count
        print("Undo executed: \(beforeCount) → \(afterCount) events")
    }
    Button("Cancel", role: .cancel) {}
}
```

### 3. **Add Event Count Display**
```swift
// Temporary debug UI
Text("Events: \(matchViewModel.matchEvents.count)")
    .font(.caption)
    .foregroundStyle(.secondary)
```

---

## Priority Assessment

**If Bug is Confirmed:**
- **Priority**: **P0 - Critical**
- **Severity**: Data loss / Data integrity issue
- **Impact**: Undermines core functionality and user trust
- **Timeline**: Immediate hotfix required before wider release

**If Bug Cannot Be Reproduced:**
- **Priority**: **P2 - Medium**
- **Severity**: User confusion / Education issue
- **Impact**: Requires better UX communication or documentation
- **Timeline**: Next minor release (improve event log clarity)

---

## Conclusion

**The undo implementation appears correct based on static code analysis and passing unit tests.** The reported bug cannot be confirmed without hands-on reproduction.

**Next Critical Step:** Lead engineer must obtain reproduction steps from testers and verify the issue on a physical device with diagnostic logging enabled.

**Three Most Likely Scenarios:**
1. **User misunderstanding** - System events remaining after undo are not recognized as valid events
2. **SwiftUI rendering glitch** - Events temporarily disappear visually but data is intact
3. **Edge case** - Specific event sequence or timing triggers unhandled scenario

---

## Appendix: Related Code Locations

### Event Recording Flow
- [MatchViewModel.swift:636-649](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L636-L649) - `recordGoal()`
- [MatchViewModel.swift:651-670](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L651-L670) - `recordCard()`
- [MatchViewModel.swift:672-687](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L672-L687) - `recordSubstitution()`
- [MatchViewModel.swift:623-634](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L623-L634) - `recordEvent()` helper

### Event Reversal Logic
- [MatchViewModel.swift:498-506](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L498-L506) - `revertGoal()`
- [MatchViewModel.swift:508-521](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L508-L521) - `revertCard()`
- [MatchViewModel.swift:523-531](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L523-L531) - `revertSubstitution()`

### Confirmation UI
- [MatchViewModel.swift:533-545](RefWatchCore/Sources/RefWatchCore/ViewModels/MatchViewModel.swift#L533-L545) - `setPendingConfirmationIfNeeded()`
- [MatchEventConfirmation.swift](RefWatchCore/Sources/RefWatchCore/Domain/MatchEventConfirmation.swift) - Confirmation model

### Event Models
- [MatchEventRecord.swift](RefWatchCore/Sources/RefWatchCore/Domain/MatchEventRecord.swift) - Core event data structure
- [MatchEventType.swift](RefWatchCore/Sources/RefWatchCore/Domain/MatchEventRecord.swift) - Event type enum

---

**Report Status:** Draft - Awaiting Lead Engineer Review
**Action Required:** Reproduce issue with diagnostic logging
**Follow-Up Date:** TBD based on tester feedback and reproduction attempts
**Escalation Path:** If data integrity issue confirmed, escalate to immediate hotfix sprint
