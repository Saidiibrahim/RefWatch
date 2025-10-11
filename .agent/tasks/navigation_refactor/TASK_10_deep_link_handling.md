---
task_id: 10
plan_id: navigation_architecture_refactor
plan_file: ../../plans/PLAN_navigation_architecture_refactor.md
title: Deep Link Handling Implementation & Testing
phase: Phase B
created: 2025-10-10
status: ⏸️ DEFERRED
priority: Low (deferred until watchOS navigation complexity increases)
estimated_minutes: 45
dependencies: [TASK_09_child_views_intents.md]
tags: [deep-linking, widgets, testing, phase-b]
---

# Task 10: Deep Link Implementation & Testing

## Objective

Thoroughly test and validate the deep link handling implemented in `MatchFlowCoordinator`. Ensure widgets, URL schemes, and Siri shortcuts can navigate correctly to any app state.

## Context

**After Task 09:**
- ✅ `MatchFlowCoordinator.handleDeepLink()` implemented
- ✅ `MatchRootView.onOpenURL` delegates to coordinator

**This Task:**
- Test all deep link scenarios
- Document URL scheme
- Add error handling
- Validate widget integration

## Supported URL Scheme

### Base Scheme
`refzone://`

### Endpoints

| URL | Behavior | Use Case |
|-----|----------|----------|
| `refzone://timer` | Navigate to active match or start flow | Widget "View Timer" |
| `refzone://start` | Start new match flow | Siri "Start a match" |
| `refzone://history` | Show saved matches list | Widget "View History" |

### State-Dependent Behavior

**`refzone://timer`:**
- If match in progress → bring user to match timer via lifecycle (navigation path cleared)
- If waiting for second half → lifecycle moves to second half kickoff (path cleared)
- If waiting for ET1/ET2 → lifecycle moves to respective kickoff (path cleared)
- If idle → show start flow (path `[.startFlow]`)

## Implementation

### 1. Enhance Error Handling

**File:** `RefZoneWatchOS/Core/Navigation/MatchFlowCoordinator.swift`

Add validation and error logging:

```swift
func handleDeepLink(_ url: URL) {
    guard url.scheme == "refzone" else {
        #if DEBUG
        print("DEBUG: MatchFlowCoordinator ignoring non-refzone URL: \(url)")
        #endif
        return
    }

    guard let host = url.host, !host.isEmpty else {
        #if DEBUG
        print("DEBUG: MatchFlowCoordinator received URL with no host: \(url)")
        #endif
        return
    }

    #if DEBUG
    print("DEBUG: MatchFlowCoordinator handling deep link: \(url)")
    #endif

    switch host {
    case "timer":
        handleTimerDeepLink()

    case "start":
        startNewMatch()

    case "history":
        showSavedMatches()

    default:
        #if DEBUG
        print("DEBUG: MatchFlowCoordinator unknown deep link host: \(host)")
        #endif
        // Unknown deep links are silently ignored in production
    }
}
```

### 2. Add Deep Link Documentation

**File:** Create `RefZoneWatchOS/Core/Navigation/DeepLinking.md`

```markdown
# Deep Linking

RefWatch supports deep linking via the `refzone://` URL scheme.

## Supported URLs

### Timer View
`refzone://timer`

Navigates to the active match timer (via lifecycle) or the start flow if no match is active.

**Smart Widget Integration:**
- Widget shows live timer data
- Tapping widget opens timer in app
- Falls back to start flow if no match

### Start Match
`refzone://start`

Directly opens the match settings screen for creating a new match.

**Siri Shortcut:**
"Hey Siri, start a match in RefWatch"

### Match History
`refzone://history`

Opens the saved matches list.

## Testing

Test deep links from Terminal:
```bash
# Timer (match active)
xcrun simctl openurl booted refzone://timer

# Start new match
xcrun simctl openurl booted refzone://start

# View history
xcrun simctl openurl booted refzone://history
```

## Adding New Deep Links

1. Add case to `MatchFlowCoordinator.handleDeepLink()`
2. Implement navigation logic
3. Update this documentation
4. Add test case in Task 10 checklist
```

### 3. Widget Integration Validation

**File:** Verify `RefZoneWidgets/RefZoneWidgets.swift`

Ensure widgets use correct URL scheme:

```swift
// In widget configuration:
Link(destination: URL(string: "refzone://timer")!) {
    // Widget content
}
```

## Testing Checklist

### Manual Testing - Simulator

#### Test 1: Timer Deep Link (Match Active)
```
Setup:
1. Start a match in app
2. Navigate to home screen
3. Tap widget OR run: xcrun simctl openurl booted refzone://timer

Expected:
- App opens to match timer (MatchSetupView)
- Timer is running
- navigationPath is empty (match surfaces driven by lifecycle)
```

#### Test 2: Timer Deep Link (Idle)
```
Setup:
1. Ensure no active match (idle state)
2. Run: xcrun simctl openurl booted refzone://timer

Expected:
- App opens to start flow
- navigationPath = [.startFlow]
```

#### Test 3: Timer Deep Link (Half-Time)
```
Setup:
1. Start a match
2. Play to half-time
3. Run: xcrun simctl openurl booted refzone://timer

- App opens to match timer
- Half-time indicator showing
- navigationPath is empty
```

#### Test 4: Start Deep Link
```
Setup:
1. App can be in any state
2. Run: xcrun simctl openurl booted refzone://start

Expected:
- App opens to match settings
- navigationPath = [.startFlow, .createMatch]
```

#### Test 5: History Deep Link
```
Setup:
1. Have some saved matches
2. Run: xcrun simctl openurl booted refzone://history

Expected:
- App opens to saved matches list
- navigationPath = [.startFlow, .savedMatches]
```

#### Test 6: Invalid Deep Link
```
Setup:
1. Run: xcrun simctl openurl booted refzone://invalid

Expected:
- App opens but doesn't navigate
- DEBUG log: "unknown deep link host: invalid"
- No crash
```

#### Test 7: Non-RefZone URL
```
Setup:
1. Run: xcrun simctl openurl booted https://example.com

Expected:
- URL ignored by MatchFlowCoordinator
- DEBUG log: "ignoring non-refzone URL"
- No navigation
```

### Widget-Specific Testing

#### Test 8: Widget Tap (Idle)
```
Setup:
1. Install widget on watch face
2. App idle
3. Tap widget

Expected:
- App launches
- Navigates to start flow
```

#### Test 9: Widget Tap (Match Active)
```
Setup:
1. Install widget
2. Start match
3. Background app
4. Tap widget from watch face

Expected:
- App foregrounds
- Shows match timer
- Timer continues running
```

#### Test 10: Widget Tap (Match Finished)
```
Setup:
1. Complete a match
2. Return to idle
3. Tap widget

Expected:
- Shows start flow (not finished screen)
```

### Siri Shortcut Testing

If Siri shortcuts are implemented:

#### Test 11: "Start a Match"
```
Setup:
1. Configure Siri shortcut
2. Invoke: "Hey Siri, start a match in RefWatch"

Expected:
- App launches to match settings
- Ready to configure match
```

### Error Handling

#### Test 12: Malformed URL
```
Setup:
1. Run: xcrun simctl openurl booted refzone://
2. Run: xcrun simctl openurl booted refzone://timer?invalid=params

Expected:
- Gracefully handled
- No crashes
- Appropriate debug logging
```

### Real Device Testing

#### Test 13: Physical Device
```
Setup:
1. Build to real Apple Watch
2. Test all deep link scenarios
3. Test widget interactions

Expected:
- Identical behavior to simulator
- Performance acceptable
```

## Acceptance Criteria

### Implementation
- [ ] Error handling added to `handleDeepLink()`
- [ ] Deep linking documentation created
- [ ] Widget URLs verified

### Testing
- [ ] All manual tests pass (Tests 1-13)
- [ ] Invalid URLs handled gracefully
- [ ] Widget integration works
- [ ] Real device tested (if available)

### Documentation
- [ ] `DeepLinking.md` created
- [ ] URL scheme documented
- [ ] Testing commands documented

## Testing Commands Reference

```bash
# Boot simulator (if not running)
xcrun simctl boot "Apple Watch SE (44mm) (2nd generation)"

# Test timer deep link
xcrun simctl openurl booted refzone://timer

# Test start deep link
xcrun simctl openurl booted refzone://start

# Test history deep link
xcrun simctl openurl booted refzone://history

# Test invalid deep link
xcrun simctl openurl booted refzone://invalid

# Open in Safari (won't work, but tests URL scheme registration)
xcrun simctl openurl booted https://refzone.app/timer

# Check logs
xcrun simctl spawn booted log stream --predicate 'subsystem contains "RefZone"'
```

## Next Steps

After completion:
- Task 11 will add unit tests for coordinator

## Notes

- Deep links are critical for widget UX
- Test both cold launch and warm launch scenarios
- Consider analytics for deep link usage
- URL scheme should be registered in Info.plist
