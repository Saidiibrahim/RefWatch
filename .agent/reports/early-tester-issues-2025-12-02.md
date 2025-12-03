# Early Tester Issues Report
**Date:** December 2, 2025
**Platform:** watchOS
**Status:** Unresolved
**Priority:** Medium
**Reporter:** Early Tester Feedback

---

## Executive Summary

Two user experience issues have been identified by early testers during match event recording on the watchOS app:

1. **Card Event Keyboard UI Inconsistency**: Users report black shading around the number keyboard when recording cards, while the same keyboard for goals appears normal.

2. **Substitution Navigation Failure**: First attempt to record a substitution fails to navigate to the keyboard input screen; second attempt succeeds.

Both issues have been confirmed and root causes identified. Issue #1 is a presentation style inconsistency with minimal UX impact. Issue #2 is a state initialization race condition that directly impairs functionality.

---

## Issue #1: Black Shading on Card Event Keyboard

### Description
When recording a card event (yellow or red), the number input keyboard displays with a dark semi-transparent background overlay. The same keyboard for goal events appears without this shading, creating an inconsistent user experience.

### User Impact
- **Severity**: Low to Medium
- **Frequency**: Every card event
- **UX Confusion**: Users perceive this as a bug or visual defect
- **Functionality**: No functional impact; keyboard works correctly

### Root Cause Analysis

The issue stems from **inconsistent presentation styles** used for different event types in `TeamDetailsView.swift`.

#### Code Location: TeamDetailsView.swift

**Goals - NavigationDestination** (Lines 36-50):
```swift
.navigationDestination(isPresented: $showingPlayerNumberInput) {
    PlayerNumberInputView(
        team: teamType,
        goalType: goalType,
        cardType: nil,
        context: "goal scorer",
        onComplete: { number in
            recordGoal(type: goalType, playerNumber: number)
            showingPlayerNumberInput = false
            selectedGoalType = nil
        }
    )
}
```

**Cards - Sheet Presentation** (Lines 52-67):
```swift
.sheet(isPresented: $showingYellowCard) {
    CardEventFlow(
        cardType: .yellow,
        team: teamType,
        matchViewModel: matchViewModel,
        setupViewModel: setupViewModel
    )
}
.sheet(isPresented: $showingRedCard) {
    CardEventFlow(
        cardType: .red,
        team: teamType,
        matchViewModel: matchViewModel,
        setupViewModel: setupViewModel
    )
}
```

#### Technical Explanation

On watchOS, the `.sheet()` modifier automatically applies a **semi-transparent dark background overlay** (scrim) to dim content behind modal presentations. This is standard Apple platform behavior to:
- Indicate modal context
- Draw visual focus to the foreground content
- Follow iOS/watchOS design guidelines

The `.navigationDestination()` modifier, by contrast, performs a navigation stack push with **no background dimming**.

The `NumericKeypad` component itself is functioning correctly in both contexts—the visual difference is entirely due to the presentation layer.

### Affected Files
- `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift:36-67`
- `RefZoneWatchOS/Features/Events/Views/CardEventFlow.swift` (presented via sheet)

### Recommended Fix

**Option 1: Standardize on NavigationDestination (Preferred)**
- Convert card flows to use `.navigationDestination` instead of `.sheet`
- Provides consistent UX across all event types
- Requires refactoring card event state management

**Option 2: Standardize on Sheet Presentation**
- Convert goal flow to use `.sheet` instead of `.navigationDestination`
- Less code changes required
- Introduces modal dimming for all events (may feel heavier)

**Option 3: Accept as Design Choice**
- Document that cards use sheet presentation intentionally
- Educate users that modal presentation is appropriate for card events
- No code changes required

### Testing Verification
1. Record a goal event → observe keyboard with no background dimming
2. Record a yellow/red card → observe keyboard with dark background overlay
3. Verify `NumericKeypad` component renders identically in both cases

---

## Issue #2: Substitution Navigation Failure on First Attempt

### Description
When attempting to record a substitution, the first tap on the substitution button fails to properly navigate to the player number input keyboard. The second attempt succeeds and navigation works as expected.

### User Impact
- **Severity**: Medium to High
- **Frequency**: First attempt only (every substitution session)
- **UX Confusion**: Users believe the button is broken or unresponsive
- **Functionality**: Requires double-tap, degrading user experience during time-sensitive match situations

### Root Cause Analysis

This is a **SwiftUI state initialization race condition** in `SubstitutionFlow.swift`.

#### Code Location: SubstitutionFlow.swift

**Initialization with Hardcoded State** (Lines 24-31):
```swift
init(team: TeamDetailsView.TeamType, matchViewModel: MatchViewModel, setupViewModel: MatchSetupViewModel) {
    self.team = team
    self.matchViewModel = matchViewModel
    self.setupViewModel = setupViewModel
    // Will be updated in body based on settings
    self._step = State(initialValue: .playerOff)  // ⚠️ Hardcoded
}
```

**Settings-Based State Update** (Lines 67-70):
```swift
.onAppear {
    // Set initial step based on settings
    step = settingsViewModel.settings.substitutionOrderPlayerOffFirst ? .playerOff : .playerOn
}
```

#### Technical Explanation: The Race Condition

**Initialization Sequence:**
1. User taps "Sub" button in `TeamDetailsView`
2. `NavigationLink` navigates to `SubstitutionFlow`
3. `SubstitutionFlow.init()` executes, setting `step = .playerOff` (hardcoded)
4. SwiftUI renders body with switch statement → shows `PlayerNumberInputView` for `.playerOff` case
5. `.onAppear` modifier fires **after initial render**
6. If `settings.substitutionOrderPlayerOffFirst == false`, step changes from `.playerOff` → `.playerOn`
7. SwiftUI triggers re-render to switch NavigationStack content
8. **watchOS NavigationStack does not handle rapid state transitions during initial appearance reliably**

**Why First Attempt Fails:**
- The NavigationStack is in an unstable state during the initial appearance phase
- Changing the displayed view immediately after appearing confuses the navigation system
- watchOS may cancel or ignore the navigation transition

**Why Second Attempt Succeeds:**
- NavigationStack is already initialized from first attempt
- No `.onAppear` race condition (view is reused or timing is different)
- State change completes before navigation renders

### Affected Files
- `RefZoneWatchOS/Features/Events/Views/SubstitutionFlow.swift:24-70`
- `RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift:113-121` (navigation trigger)

### Recommended Fix

**Solution: Initialize State Correctly from Settings**

Modify `SubstitutionFlow.init()` to read settings during initialization instead of using `.onAppear`:

```swift
init(team: TeamDetailsView.TeamType, matchViewModel: MatchViewModel, setupViewModel: MatchSetupViewModel) {
    self.team = team
    self.matchViewModel = matchViewModel
    self.setupViewModel = setupViewModel

    // FIXED: Initialize step based on settings immediately
    let settingsViewModel = SettingsViewModel()  // Or inject via parameter
    let initialStep: SubstitutionStep = settingsViewModel.settings.substitutionOrderPlayerOffFirst
        ? .playerOff
        : .playerOn
    self._step = State(initialValue: initialStep)
}
```

Then **remove** the `.onAppear` modifier (lines 67-70) entirely.

**Alternative: Use @AppStorage for Settings**

If settings are persisted via `@AppStorage`, read the value directly during initialization:

```swift
init(team: TeamDetailsView.TeamType, matchViewModel: MatchViewModel, setupViewModel: MatchSetupViewModel) {
    self.team = team
    self.matchViewModel = matchViewModel
    self.setupViewModel = setupViewModel

    // Read setting directly from UserDefaults
    let orderPlayerOffFirst = UserDefaults.standard.bool(forKey: "substitutionOrderPlayerOffFirst")
    let initialStep: SubstitutionStep = orderPlayerOffFirst ? .playerOff : .playerOn
    self._step = State(initialValue: initialStep)
}
```

### Testing Verification
1. Set `substitutionOrderPlayerOffFirst = true` in settings
2. Tap substitution button → verify immediate navigation to "player off" keyboard
3. Set `substitutionOrderPlayerOffFirst = false` in settings
4. Tap substitution button → verify immediate navigation to "player on" keyboard
5. Repeat steps 10+ times to ensure no navigation failures

---

## Dependency Analysis

### Shared Components
Both issues interact with:
- `NumericKeypad.swift` (keyboard component - not the source of either issue)
- `PlayerNumberInputView.swift` (wrapper around NumericKeypad)

### Settings Dependencies
Issue #2 requires access to `SettingsViewModel` during initialization. Current architecture may need adjustment to:
- Inject `SettingsViewModel` into `SubstitutionFlow.init()`
- Use `@AppStorage` for settings persistence
- Access `UserDefaults` directly during initialization

---

## Priority Recommendation

**Issue #1 (Black Shading):**
- Priority: **P2 - Medium**
- Rationale: Visual inconsistency, but no functional impact
- Timeline: Can be addressed in next minor release

**Issue #2 (Navigation Failure):**
- Priority: **P1 - High**
- Rationale: Functional degradation during time-sensitive match operations
- Timeline: Should be fixed in next patch release

---

## Additional Notes

### watchOS Navigation Best Practices
Per Apple's documentation, state changes within `NavigationStack` should:
1. Initialize state correctly before first render
2. Avoid state mutations in `.onAppear` when possible
3. Use `.task` for async initialization if needed
4. Test extensively on physical devices (simulator may not reproduce timing issues)

### Related Code Review Suggestions
Consider auditing other event flows for similar patterns:
- `CardEventFlow.swift` - appears to use coordinator pattern correctly
- `GoalTypeSelectionView.swift` - uses selection callback (no navigation state issues)
- Other flows using `.onAppear` for state initialization

---

## Appendix: File References

### Issue #1 - Card Keyboard Shading
- [TeamDetailsView.swift:36-67](RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift#L36-L67)
- [CardEventFlow.swift](RefZoneWatchOS/Features/Events/Views/CardEventFlow.swift)
- [PlayerNumberInputView.swift](RefZoneWatchOS/Features/Events/Views/PlayerNumberInputView.swift)
- [NumericKeypad.swift](RefZoneWatchOS/Core/Components/Input/NumericKeypad.swift)

### Issue #2 - Substitution Navigation
- [SubstitutionFlow.swift:24-70](RefZoneWatchOS/Features/Events/Views/SubstitutionFlow.swift#L24-L70)
- [TeamDetailsView.swift:113-121](RefZoneWatchOS/Features/MatchSetup/Views/TeamDetailsView.swift#L113-L121)
- [AdaptiveEventGrid.swift:100-113](RefZoneWatchOS/Core/Components/AdaptiveEventGrid.swift#L100-L113)

---

**Report Prepared By:** Claude Code Analysis
**Review Status:** Pending Senior Engineer Review
**Next Steps:** Awaiting prioritization and implementation assignment
