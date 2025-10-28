---
task_id: 04
plan_id: PLAN_healthkit_authorization_fixes
plan_file: ../../plans/PLAN_healthkit_authorization_fixes.md
title: Implement hybrid onboarding flow (first-launch sheet + persistent banner + enhanced card)
phase: Phase 2 - UX Architecture Improvements
---

# TASK_04: Implement Hybrid Onboarding Flow

## Objective

Create a multi-touchpoint authorization flow that educates users about HealthKit requirements early, provides multiple opportunities to grant permissions, and handles different user journeys gracefully.

## Background

Phase 1 fixes critical bugs but doesn't address fundamental UX issues:
- No proactive education about HealthKit requirements
- Authorization card can be missed if user scrolls past it
- No persistent reminder after scrolling away
- First-time users get no context before seeing carousel

Phase 2 implements a **progressive permission flow** that balances user agency with effective conversion:
1. **First launch**: Lightweight welcome sheet explains HealthKit benefits
2. **Inline card**: Authorization card in carousel for later access
3. **Persistent banner**: Optional reminder when scrolled away from auth card
4. **Enhanced card**: Improved visual prominence and messaging

## Architecture Overview

```
User Opens Workout Mode
         ↓
    Has user seen welcome?
         ↓
    NO ──→ Show Welcome Sheet
           ├─ "Grant Now" → Request Auth → Dismiss
           └─ "Later" → Dismiss
         ↓
    YES → Show Carousel
           ↓
       Is authorized?
           ↓
    NO ──→ Show Auth Card (first item)
           ├─ User scrolls away?
           │  └─ Show Persistent Banner (optional)
           └─ User taps card → Request Auth
```

## Components to Build

### 1. First-Launch Welcome Sheet

**New File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutWelcomeView.swift`

```swift
import SwiftUI
import RefWatchCore

struct WorkoutWelcomeView: View {
  let onGrantNow: () -> Void
  let onDismiss: () -> Void

  @Environment(\.theme) private var theme

  var body: some View {
    VStack(spacing: theme.spacing.stackLG) {
      // Icon
      Image(systemName: "heart.text.square.fill")
        .font(.system(size: 48, weight: .medium))
        .foregroundStyle(theme.colors.accentSecondary)

      // Title & Description
      VStack(spacing: theme.spacing.stackSM) {
        Text("Track Your Training")
          .font(theme.typography.cardHeadline)
          .foregroundStyle(theme.colors.textPrimary)
          .multilineTextAlignment(.center)

        Text("RefZone uses HealthKit to track pace, distance, and heart rate during workouts. Grant access on your paired iPhone.")
          .font(theme.typography.body)
          .foregroundStyle(theme.colors.textSecondary)
          .multilineTextAlignment(.center)
      }

      // Actions
      VStack(spacing: theme.spacing.stackSM) {
        Button(action: onGrantNow) {
          Text("Grant on iPhone")
            .font(theme.typography.button)
            .foregroundStyle(theme.colors.textInverted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.s)
            .background(
              RoundedRectangle(cornerRadius: theme.components.controlCornerRadius)
                .fill(theme.colors.accentSecondary)
            )
        }
        .buttonStyle(.plain)

        Button(action: onDismiss) {
          Text("Set Up Later")
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(theme.spacing.stackXL)
    .background(theme.colors.backgroundElevated)
  }
}

#Preview {
  WorkoutWelcomeView(
    onGrantNow: {},
    onDismiss: {}
  )
  .theme(DefaultTheme())
}
```

### 2. Persistent Banner Component

**New File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutAuthorizationBanner.swift`

```swift
import SwiftUI
import RefWatchCore

struct WorkoutAuthorizationBanner: View {
  let onTap: () -> Void

  @Environment(\.theme) private var theme

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: theme.spacing.s) {
        Image(systemName: "heart.text.square.fill")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(theme.colors.accentSecondary)

        VStack(alignment: .leading, spacing: 2) {
          Text("Grant Health Access")
            .font(theme.typography.caption.bold())
            .foregroundStyle(theme.colors.textPrimary)

          Text("Required to track workouts")
            .font(theme.typography.metadata)
            .foregroundStyle(theme.colors.textSecondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(theme.colors.textTertiary)
      }
      .padding(.horizontal, theme.spacing.m)
      .padding(.vertical, theme.spacing.s)
      .background(
        RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
          .fill(theme.colors.backgroundSecondary)
          .overlay(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
              .stroke(theme.colors.accentSecondary.opacity(0.3), lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  WorkoutAuthorizationBanner(onTap: {})
    .padding()
    .theme(DefaultTheme())
}
```

### 3. Enhanced Authorization Card Styling

**File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift`

Update `borderColor` property in `WorkoutSelectionTileView` (lines 212-217):

```swift
private var borderColor: Color {
  // Special styling for authorization card
  if case .authorization = item.content {
    return theme.colors.accentSecondary.opacity(0.6)
  }

  if case .locked(let id, _) = dwellState, id == item.id {
    return theme.colors.accentSecondary
  }

  return theme.colors.outlineMuted
}
```

And update background opacity in `tileContent` (line 186):

```swift
.background(
  RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
    .fill(
      isFocused ? theme.colors.backgroundElevated :
      (item.content.isAuthorizationCard ? theme.colors.backgroundSecondary.opacity(0.8) : theme.colors.backgroundSecondary)
    )
    .overlay(
      RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
        .stroke(borderColor, lineWidth: isFocused ? 2 : (item.content.isAuthorizationCard ? 1.5 : 1))
    )
)
```

Add helper to `WorkoutSelectionItem.Content`:

```swift
extension WorkoutSelectionItem.Content {
  var isAuthorizationCard: Bool {
    if case .authorization = self { return true }
    return false
  }
}
```

### 4. ViewModel Integration

**File**: `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`

Add welcome sheet state:

```swift
@Published var showWelcomeSheet = false
@Published var showAuthorizationBanner = false

private let hasSeenWelcomeKey = "workout.hasSeenWelcome"
```

Add welcome sheet logic to `bootstrap()`:

```swift
func bootstrap() async {
  await refreshAuthorization()
  await loadPresets()
  await loadHistory()

  // Show welcome sheet on first launch if not authorized
  await MainActor.run {
    let hasSeenWelcome = UserDefaults.standard.bool(forKey: hasSeenWelcomeKey)
    if !hasSeenWelcome && !authorization.isAuthorized {
      showWelcomeSheet = true
    }
  }
}
```

Add welcome sheet handlers:

```swift
func handleWelcomeGrantNow() {
  UserDefaults.standard.set(true, forKey: hasSeenWelcomeKey)
  showWelcomeSheet = false
  requestAuthorization()
}

func handleWelcomeDismiss() {
  UserDefaults.standard.set(true, forKey: hasSeenWelcomeKey)
  showWelcomeSheet = false
}
```

Add banner visibility logic:

```swift
func updateAuthorizationBannerVisibility(currentlyFocusedID: WorkoutSelectionItem.ID?) {
  // Show banner if:
  // 1. User is not authorized
  // 2. Focus is NOT on authorization card
  // 3. User has seen welcome (dismissed or granted)

  let hasSeenWelcome = UserDefaults.standard.bool(forKey: hasSeenWelcomeKey)
  let isViewingAuthCard = currentlyFocusedID == .authorization

  showAuthorizationBanner = !authorization.isAuthorized && !isViewingAuthCard && hasSeenWelcome
}
```

### 5. View Integration

**File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutRootView.swift`

Update to include welcome sheet and banner:

```swift
var body: some View {
  ZStack {
    switch viewModel.presentationState {
    case .list:
      VStack(spacing: 0) {
        // Authorization banner (if needed)
        if viewModel.showAuthorizationBanner {
          WorkoutAuthorizationBanner {
            // Scroll to authorization card
            viewModel.focusedSelectionID = .authorization
          }
          .padding(.horizontal)
          .padding(.vertical, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
        }

        // Main carousel
        WorkoutHomeView(
          items: viewModel.selectionItems,
          focusedSelectionID: viewModel.focusedSelectionID,
          dwellState: viewModel.dwellState,
          dwellConfiguration: viewModel.selectionDwellConfiguration,
          isBusy: viewModel.isPerformingAction,
          onFocusChange: viewModel.updateFocusedSelection,
          onSelect: viewModel.requestPreview,
          onRequestAccess: viewModel.requestAuthorization,
          onReloadPresets: viewModel.reloadPresets
        )
        .onChange(of: viewModel.focusedSelectionID) { newID in
          viewModel.updateAuthorizationBannerVisibility(currentlyFocusedID: newID)
        }
      }

    case .preview(let item):
      // ... existing preview code
    }
  }
  .sheet(isPresented: $viewModel.showWelcomeSheet) {
    WorkoutWelcomeView(
      onGrantNow: viewModel.handleWelcomeGrantNow,
      onDismiss: viewModel.handleWelcomeDismiss
    )
  }
}
```

## Implementation Checklist

### Phase 2A: Welcome Sheet
- [ ] Create `WorkoutWelcomeView.swift` with themed styling
- [ ] Add `showWelcomeSheet` and `hasSeenWelcomeKey` to ViewModel
- [ ] Update `bootstrap()` to show sheet on first launch
- [ ] Add `handleWelcomeGrantNow()` and `handleWelcomeDismiss()` handlers
- [ ] Integrate sheet in `WorkoutRootView` with `.sheet()` modifier
- [ ] Test first-launch flow with fresh install

### Phase 2B: Persistent Banner (Optional)
- [ ] Create `WorkoutAuthorizationBanner.swift` component
- [ ] Add `showAuthorizationBanner` state to ViewModel
- [ ] Implement `updateAuthorizationBannerVisibility()` logic
- [ ] Integrate banner in `WorkoutRootView` above carousel
- [ ] Add scroll-to-auth-card action on banner tap
- [ ] Test banner appears/disappears based on focus

### Phase 2C: Enhanced Card Styling
- [ ] Update `borderColor` to highlight authorization card
- [ ] Adjust background opacity for authorization card
- [ ] Add `isAuthorizationCard` helper to Content enum
- [ ] Test visual prominence on actual watch
- [ ] Verify contrast meets accessibility standards

### Phase 2D: Integration Testing
- [ ] Test full flow: welcome → grant → carousel updates
- [ ] Test skip flow: welcome → later → banner → tap → scroll to card
- [ ] Test returning user: no welcome sheet shown
- [ ] Test partial auth: limited state shows appropriate messaging
- [ ] Test accessibility: VoiceOver, Dynamic Type

## Testing

### User Journey Tests

**First-Time User - Happy Path**:
1. Fresh install, open workout mode
2. **Expected**: Welcome sheet appears
3. Tap "Grant on iPhone"
4. **Expected**: Sheet dismisses, auth request sent to iPhone
5. Grant on iPhone Health app
6. **Expected**: Carousel loads, no authorization card (or updates immediately)

**First-Time User - Deferred Path**:
1. Fresh install, open workout mode
2. **Expected**: Welcome sheet appears
3. Tap "Set Up Later"
4. **Expected**: Sheet dismisses, carousel shows with auth card first
5. Scroll past auth card
6. **Expected**: Persistent banner appears at top
7. Tap banner
8. **Expected**: Scrolls back to authorization card

**Returning User**:
1. User has already seen welcome
2. Open workout mode
3. **Expected**: No welcome sheet, goes straight to carousel
4. If not authorized, auth card visible
5. If authorized, no auth card or banner

### Edge Cases

**Partial Authorization**:
1. User grants core permissions but denies optional metrics
2. **Expected**: Authorization card shows "Limited Access" state
3. Welcome sheet not shown (user already addressed permissions)
4. Banner behavior depends on design decision (show or hide for limited?)

**Authorization State Changes**:
1. User revokes permissions in iPhone Settings while app is open
2. **Expected**: Next refresh shows authorization card again
3. Welcome sheet NOT shown (user already interacted with permissions)

**Quick Successive Launches**:
1. User opens workout mode, dismisses welcome, closes app
2. User opens workout mode again immediately
3. **Expected**: Welcome sheet NOT shown again (`hasSeenWelcome` is persistent)

## Files Created/Modified

**New Files:**
- `RefZoneWatchOS/Features/Workout/Views/WorkoutWelcomeView.swift`
- `RefZoneWatchOS/Features/Workout/Views/WorkoutAuthorizationBanner.swift` (optional)

**Modified Files:**
- `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`
  - Add welcome sheet state and handlers
  - Add banner visibility logic
  - Update `bootstrap()` for welcome flow

- `RefZoneWatchOS/Features/Workout/Views/WorkoutRootView.swift`
  - Add welcome sheet presentation
  - Add banner integration (optional)
  - Wire up state changes

- `RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift`
  - Enhance authorization card styling
  - Add border and background emphasis

## Dependencies

- Requires Phase 1 tasks (TASK_01, TASK_02, TASK_03) to be completed first
- Requires `RefWatchCore` theme system for styling
- Uses `@AppStorage` or `UserDefaults` for persistence

## Estimated Effort

**3-4 hours** (all components + testing)
- Welcome sheet: 1 hour
- Banner component: 1 hour
- Integration: 1 hour
- Testing & polish: 1 hour

## Notes

### Design Decisions

**Welcome Sheet vs. Full Onboarding Flow**:
- Using lightweight sheet instead of multi-screen onboarding
- Rationale: Workout mode is a feature, not the whole app. Keep it simple.

**Banner Optionality**:
- Banner is marked optional because it may feel intrusive on small watch screen
- Test with real users to decide if it's helpful or annoying
- Can ship without banner initially, add later if discoverability is still an issue

**State Persistence**:
- Using `UserDefaults` for `hasSeenWelcome` flag
- Alternative: Track in CloudKit/iCloud for cross-device sync
- Decision: Local is sufficient - welcome sheet is device-specific

### Future Enhancements

- **Throttling**: Use `lastPromptedAt` from `HealthKitWorkoutAuthorizationManager` to avoid spamming iPhone prompts
- **Analytics**: Track welcome sheet conversion (granted vs. later vs. dismissed)
- **A/B Testing**: Test different welcome copy, button labels, or timing
- **Haptics**: Add subtle haptic when welcome sheet appears or when scrolling to auth card
- **Animation**: Polish sheet presentation and banner slide-in transitions

### Accessibility Considerations

- Welcome sheet must support VoiceOver with clear labels
- Banner should be dismissible via VoiceOver swipe actions
- All text must scale with Dynamic Type
- Color contrast must meet WCAG AA standards (especially banner)
