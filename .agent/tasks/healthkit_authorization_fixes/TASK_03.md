---
task_id: 03
plan_id: PLAN_healthkit_authorization_fixes
plan_file: ../../plans/PLAN_healthkit_authorization_fixes.md
title: Update authorization copy to mention iPhone requirement
phase: Phase 1 - Critical Bug Fixes
---

# TASK_03: Update Authorization Copy to Mention iPhone

## Objective

Update all user-facing authorization messages and button titles to explicitly mention that permission grants happen on the paired iPhone, not on the watch. This eliminates user confusion when they tap "Grant Access" and nothing appears on their watch screen.

## Problem

Current copy in two locations makes no reference to iPhone:

1. **Authorization Messages** (`WorkoutModeViewModel.swift:222-236`): Subtitle text shown on authorization card
2. **Button Titles** (`WorkoutHomeView.swift:247-258`): CTA button text

Users tap "Grant Access" expecting a watch dialog, but the permission sheet appears on their iPhone. Without this context, users think the app is broken.

## Solution

### Part A: Update Authorization Messages

**Location**: `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift:222-236`

**Current Code**:
```swift
private static func authorizationMessage(for status: WorkoutAuthorizationStatus) -> String {
  switch status.state {
  case .notDetermined:
    return "Allow RefZone to collect pace, distance, and heart rate."
  case .denied:
    return "Enable Health permissions in Settings to track workouts."
  case .limited:
    return "Grant full access for complete workout analytics."
  case .authorized:
    if status.hasOptionalLimitations {
      return "Optional metrics are disabled. Enable them for richer stats."
    }
    return "Health permissions are active."
  }
}
```

**Updated Code**:
```swift
private static func authorizationMessage(for status: WorkoutAuthorizationStatus) -> String {
  switch status.state {
  case .notDetermined:
    return "Grant access on your paired iPhone to track pace, distance, and heart rate."
  case .denied:
    return "Enable Health permissions on iPhone Settings to track workouts."
  case .limited:
    return "Grant full access on iPhone for complete workout analytics."
  case .authorized:
    if status.hasOptionalLimitations {
      return "Optional metrics are disabled. Enable them on iPhone for richer stats."
    }
    return "Health permissions are active."
  }
}
```

**Changes Summary**:
- `.notDetermined`: "Allow RefZone to collect..." → "Grant access **on your paired iPhone** to track..."
- `.denied`: "Enable Health permissions **in Settings**..." → "Enable Health permissions **on iPhone Settings**..."
- `.limited`: "Grant full access..." → "Grant full access **on iPhone**..."
- `.authorized` with optional limitations: "Enable them..." → "Enable them **on iPhone**..."

### Part B: Update Button Titles

**Location**: `RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift:247-258`

**Current Code**:
```swift
private var authorizationButtonTitle: String {
  switch item.authorizationStatus?.state {
  case .notDetermined:
    return "Grant Access"
  case .denied:
    return "Review Access"
  case .limited:
    return "Review Access"
  default:
    return "Manage Access"
  }
}
```

**Updated Code**:
```swift
private var authorizationButtonTitle: String {
  switch item.authorizationStatus?.state {
  case .notDetermined:
    return "Grant on iPhone"
  case .denied:
    return "Fix on iPhone"
  case .limited:
    return "Update on iPhone"
  default:
    return "Manage on iPhone"
  }
}
```

**Changes Summary**:
- `.notDetermined`: "Grant Access" → "**Grant on iPhone**"
- `.denied`: "Review Access" → "**Fix on iPhone**"
- `.limited`: "Review Access" → "**Update on iPhone**"
- `default`: "Manage Access" → "**Manage on iPhone**"

## Copy Rationale

### Message Style (Subtitle Text)

Using natural language phrases like "on your paired iPhone" and "on iPhone Settings":
- **Clarity**: Explicitly states where the action will take place
- **Context**: "Paired iPhone" on first mention establishes the relationship
- **Subsequent mentions**: Shorter "on iPhone" keeps consistency without repetition

### Button Style (CTA Text)

Using concise "Verb + on iPhone" format:
- **Brevity**: Fits small watch screen and button constraints
- **Action-oriented**: Starts with verb (Grant, Fix, Update, Manage)
- **Clarity**: "on iPhone" suffix is consistent and immediately sets expectations
- **Accessibility**: Short labels work better with VoiceOver and Dynamic Type

### Alternative Wording Considered

**Option A: "Check iPhone"**
- Pros: Very short, emphasizes device switch
- Cons: Passive, doesn't convey what user does on iPhone

**Option B: "Approve on iPhone"**
- Pros: Clear action verb
- Cons: Doesn't fit denied/limited states well

**Option C: "Open Health App"**
- Pros: Specific next step
- Cons: Too prescriptive, may change with iOS versions

**Selected**: "Verb + on iPhone" provides best balance of clarity, brevity, and flexibility across states.

## Testing

### Manual Testing

**Visual Review**:
1. Reset HealthKit permissions
2. Open RefWatch workout mode
3. Read authorization card subtitle → should mention "paired iPhone"
4. Read button text → should say "Grant on iPhone"
5. Verify text fits within card bounds (no truncation)
6. Test with Larger Text accessibility setting → verify text still readable

**State Coverage**:
Test all authorization states to verify copy:

| State | Expected Subtitle | Expected Button |
|-------|------------------|-----------------|
| Not Determined | "Grant access on your paired iPhone to track..." | "Grant on iPhone" |
| Denied | "Enable Health permissions on iPhone Settings..." | "Fix on iPhone" |
| Limited | "Grant full access on iPhone for complete..." | "Update on iPhone" |
| Authorized (with optional denied) | "Optional metrics are disabled. Enable them on iPhone..." | "Update on iPhone" |
| Authorized (full) | "Health permissions are active." | (card hidden) |

**Interaction Flow**:
1. Tap "Grant on iPhone" button
2. Check iPhone → Health app permission sheet should appear
3. Grant permissions on iPhone
4. Return to watch → authorization card should disappear (if TASK_01 is complete)

### Accessibility Testing

**VoiceOver**:
1. Enable VoiceOver on Apple Watch
2. Swipe to authorization card
3. Verify VoiceOver reads: title, subtitle with "on iPhone" context, button with "on iPhone" suffix
4. Verify reading order makes sense

**Dynamic Type**:
1. Enable Larger Text in watch Settings → Accessibility
2. Set to maximum size
3. Verify authorization card text doesn't truncate
4. Verify button text remains on one line (or wraps gracefully)

### Copy Review Checklist

- [ ] Every authorization message mentions "iPhone" or "paired iPhone"
- [ ] Button titles clearly indicate action happens on iPhone
- [ ] Copy is concise enough for small watch screen
- [ ] Language is consistent across all states
- [ ] Tone is helpful and instructional, not demanding or technical
- [ ] Text is accessible (VoiceOver, Dynamic Type)

## Files Modified

- `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`
  - Lines 224-234: Update all authorization message strings to mention iPhone

- `RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift`
  - Lines 249-256: Update all button title strings to include "on iPhone"

## Dependencies

None - purely copy changes, no logic or API modifications.

## Estimated Effort

**20 minutes** (copy updates + accessibility testing)

## Notes

### Future Enhancements

Consider adding an icon next to the button:
```swift
Label("Grant on iPhone", systemImage: "iphone")
```

This provides a visual cue alongside the text. However, this requires UI layout changes and should be evaluated for small screen constraints.

### Localization Considerations

If RefWatch will be localized in the future:
- Ensure "iPhone" is correctly handled (it's a product name, typically not translated)
- Test that localized strings don't truncate on small watch screens
- Some languages may need shorter phrasing to fit button constraints

### Consistency with iOS App

If the iOS companion app has similar authorization flows, ensure terminology is consistent:
- Use same action verbs (Grant, Fix, Update, Manage)
- Use same messaging style for permission explanations

### Copy Approval

Since this changes user-facing text, consider:
- Product/UX review of new copy
- Testing with real users to validate clarity
- A/B testing different phrasings if conversion is critical
