# ExecPlan: HealthKit Authorization Fixes & UX Improvements

## Purpose / Big Picture

Users will experience a seamless HealthKit authorization flow on watchOS that:
1. **Updates immediately** after granting permissions (no stuck authorization card)
2. **Prevents confusion** by blocking workout starts when permissions are missing, with clear actionable errors
3. **Sets clear expectations** by telling users upfront that authorization happens on their paired iPhone
4. **Guides effectively** through multiple touchpoints (first launch, carousel card, just-in-time alerts)

After these changes, users will understand the authorization requirements, grant permissions on their iPhone, see the UI update instantly, and successfully start workouts without encountering cryptic HealthKit errors.

## Surprises & Discoveries

- **Observation**: `requestAuthorization()` updates state but never calls `rebuildSelectionItems()`, causing the authorization card to persist even after successful grant
  - **Evidence**: Compare `WorkoutModeViewModel.swift:691-694` (refreshAuthorization - calls rebuild) vs `696-724` (requestAuthorization - missing rebuild call)

- **Observation**: No authorization guard before starting workouts, leading to generic HealthKit collection errors instead of clear permission errors
  - **Evidence**: `WorkoutModeViewModel.swift:639-668` (beginStartingSession) has no check for `authorization.isAuthorized`

- **Observation**: No UI copy mentions that permission grants happen on the paired iPhone, not the watch
  - **Evidence**: `WorkoutModeViewModel.swift:222-235` and `WorkoutHomeView.swift:247-258` contain no iPhone references

- **Observation**: Once users scroll past the authorization card in the carousel, there's no persistent way to find it again
  - **Evidence**: `WorkoutHomeView.swift:25-114` shows standard carousel with no banner or persistent reminder

## Decision Log

- **Decision**: Split work into two phases - critical bugs first (Phase 1), UX enhancements second (Phase 2)
  - **Rationale**: Bugs are blocking user workflows and causing confusion. Fix these immediately before architectural improvements.
  - **Date/Author**: 2025-10-28 / Claude

- **Decision**: Add `rebuildSelectionItems()` call immediately after authorization update, plus optional delayed refresh
  - **Rationale**: Ensures UI updates synchronously, with fallback refresh in case iPhone approval takes time
  - **Date/Author**: 2025-10-28 / Claude

- **Decision**: Place authorization guard at the start of `beginStartingSession()` rather than in individual workout type handlers
  - **Rationale**: Centralized check catches all workout start paths (quick start, preset, last completed)
  - **Date/Author**: 2025-10-28 / Claude

- **Decision**: Update all authorization copy to explicitly mention "iPhone" or "paired iPhone"
  - **Rationale**: watchOS HealthKit authorization requires iPhone interaction - this is non-obvious and causes user confusion
  - **Date/Author**: 2025-10-28 / Claude

## Outcomes & Retrospective

*(To be completed after implementation)*

## Context and Orientation

### Current State

RefWatch is a watchOS-first referee app with a workout mode feature. The workout feature uses HealthKit to track fitness metrics during training sessions.

**Key Architecture:**
- **WorkoutModeViewModel** (`RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`): Manages workout state, authorization, and selection items for the carousel
- **WorkoutHomeView** (`RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift`): Displays scrollable carousel of workout options, including an authorization card when permissions aren't granted
- **HealthKitWorkoutAuthorizationManager** (in `RefWorkoutCore`): Handles actual HealthKit authorization requests

### Key Terms

- **Authorization Card**: A carousel item shown when HealthKit permissions aren't granted, with CTA to request access
- **Selection Items**: The array of workout options (authorization, last completed, quick starts, presets) displayed in the carousel
- **Just-in-Time Guard**: A pre-flight check that validates authorization before attempting to start a workout session
- **iPhone Handoff**: On watchOS, HealthKit permission dialogs appear on the paired iPhone, not the watch - users must approve there

### Current Flow

1. User opens workout mode → `WorkoutModeViewModel.bootstrap()` checks authorization status
2. If not authorized → authorization card added to `selectionItems` via `rebuildSelectionItems()`
3. User taps "Grant Access" → calls `requestAuthorization()` → triggers iPhone dialog
4. **BUG**: Authorization card never disappears even after grant (missing rebuild call)
5. User taps workout → **BUG**: No pre-check, starts session, HealthKit fails with generic error

## Plan of Work

### Phase 1: Critical Bug Fixes (Immediate)

#### Step 1: Fix Authorization Refresh Bug
**File**: `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`
**Location**: Line 702 (inside `requestAuthorization()` success path)

Add `rebuildSelectionItems()` call after updating `self.authorization = status` to ensure carousel updates immediately. Optionally add a delayed refresh to handle async iPhone approval timing.

#### Step 2: Add Just-In-Time Authorization Guard
**File**: `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift`
**Location**: Line 645 (at start of `beginStartingSession()`)

Run `cancelPendingDwell()` before checking authorization so dwell locks always clear, then guard on `authorization.isAuthorized` before toggling `isPerformingAction`. When the guard fails, surface `.authorizationDenied` via the presentation state and accompanying error/recovery strings.

#### Step 3: Update Authorization Copy - Messages & Errors
**Files**:
- `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift` (lines 222-236 `authorizationMessage(for:)` and the authorization card title cases)
- `RefZoneWatchOS/Features/Workout/ViewModels/WorkoutModeViewModel.swift` (lines 20-47 `WorkoutError.authorizationDenied` strings)

Revise all authorization messaging to explicitly mention the paired iPhone. This includes the card subtitle helper, the authorization tile titles (e.g., "Grant on iPhone"), and the error/recovery text that appears in preview and alert flows.

#### Step 4: Update Authorization Copy - Button Titles
**File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift`
**Location**: Lines 247-258 (`authorizationButtonTitle`)

Change button titles to include "on iPhone" suffix (e.g., "Grant on iPhone", "Fix on iPhone") for clarity.

### Phase 2: UX Architecture Improvements (Follow-up)

#### Step 5: Create First-Launch Welcome Sheet
**New File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutWelcomeView.swift`

Build a lightweight sheet shown on first app launch explaining HealthKit benefits and iPhone requirement, with "Grant Now" and "Later" options. Use `@AppStorage` to track if user has seen it.

#### Step 6: Add Persistent Authorization Banner
**File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift`

Add banner component above carousel when permissions aren't granted and user has scrolled away from authorization card. Banner provides quick access to grant permissions.

#### Step 7: Enhance Authorization Card Visual Prominence
**File**: `RefZoneWatchOS/Features/Workout/Views/WorkoutHomeView.swift`

Improve styling of authorization card with stronger border colors, priority badge, or haptic feedback when scrolling to it.

## Concrete Steps

Tasks are documented in `.agent/tasks/healthkit_authorization_fixes/`:

- **TASK_01**: Fix requestAuthorization() refresh bug
- **TASK_02**: Add just-in-time authorization guard
- **TASK_03**: Update authorization copy to mention iPhone
- **TASK_04**: Implement hybrid onboarding flow (Phase 2)

## Progress

### Phase 1: Critical Bugs
- [ ] (TASK_01.md) Fix requestAuthorization() to rebuild selection items after authorization grant
- [ ] (TASK_02.md) Add pre-flight authorization check in beginStartingSession()
- [ ] (TASK_03.md) Update all authorization messages and button titles to reference iPhone

### Phase 2: UX Enhancements
- [ ] (TASK_04.md) Create first-launch welcome sheet with authorization primer
- [ ] (TASK_04.md) Add persistent banner for authorization access
- [ ] (TASK_04.md) Enhance authorization card visual prominence

## Testing Approach

### Phase 1 Testing

**Manual Test Cases:**
1. **Authorization Refresh Test**
   - Reset HealthKit permissions in iOS Settings
   - Open RefWatch on watch → see authorization card
   - Tap "Grant Access" → approve on iPhone Health app
   - **Expected**: Authorization card disappears immediately from carousel
   - **Bug if**: Card persists until user navigates away and back

2. **Just-In-Time Guard Test**
   - Reset HealthKit permissions
   - Open RefWatch → scroll past authorization card
   - Tap any workout card
   - **Expected**: Clear error alert saying "HealthKit access denied" with recovery action
   - **Bug if**: Generic collection error or session start attempt without clear guidance

3. **iPhone Copy Test**
   - Reset HealthKit permissions
   - Read all authorization card text and button labels
   - **Expected**: Every message mentions "iPhone" or "paired iPhone"
   - **Bug if**: Any copy suggests watch-local authorization

### Phase 2 Testing

**First-Launch Flow:**
1. Fresh install → welcome sheet appears with HealthKit explanation
2. Tap "Grant Now" → guided to iPhone → approve → sheet dismisses → carousel shows workouts
3. Tap "Later" → sheet dismisses → carousel shows authorization card for later access

**Persistence Testing:**
1. Grant partial permissions (deny optional metrics)
2. Verify authorization card shows "Limited Access" state with diagnostics
3. Tap "Update on iPhone" → re-prompts on iPhone with missing metrics highlighted

### Automated Testing

Update `WorkoutModeViewModelTests.swift` to cover:
- `requestAuthorization()` calls `rebuildSelectionItems()` after success
- `beginStartingSession()` returns early with auth error when `!isAuthorized`
- Authorization card removed from selection items after full grant
- Authorization card remains visible for limited/denied states with updated messaging

## Constraints & Considerations

### Technical Constraints
- **watchOS HealthKit Limitation**: All permission dialogs appear on paired iPhone, not the watch. Cannot be changed - must work around with clear messaging.
- **Authorization Privacy**: HealthKit doesn't return whether user denied read permissions (returns empty results instead). We can only detect write denials and "not determined" states.
- **Async Timing**: iPhone approval may take seconds depending on user response time. UI must handle both immediate and delayed authorization state changes.

### UX Considerations
- **Non-Blocking Philosophy**: Don't force permissions before letting users explore. Progressive disclosure is better for conversion.
- **Small Screen Real Estate**: watchOS has limited space - avoid persistent banners that crowd the UI. Use them sparingly.
- **Haptic Budget**: Don't overuse haptics for authorization nudges - can feel naggy. Reserve for positive confirmation (successful grant).

### Code Considerations
- **Existing lastPromptedAt**: `HealthKitWorkoutAuthorizationManager` tracks last prompt time but doesn't currently use it for throttling. Consider implementing throttle logic to avoid spamming iPhone dialogs.
- **State Synchronization**: `authorization` state in ViewModel must stay in sync with actual HealthKit state. Consider periodic background refresh.
- **Error Mapping**: Current error mapping in `beginStartingSession()` doesn't distinguish authorization errors from session errors. Need explicit auth check before generic error handling.

### Platform Guidelines
- **Apple HIG**: Request permissions in context, explain benefits clearly, respect user choice to decline
- **Privacy Requirements**: Info.plist must contain usage descriptions (already present)
- **Accessibility**: All authorization UI must work with VoiceOver and Dynamic Type

### Migration Considerations
- **Existing Users**: Users who already granted permissions won't see welcome sheet (use `@AppStorage` flag)
- **Partial Grants**: Some users have granted core permissions but denied optional metrics - must handle gracefully with "limited access" messaging
- **Version Compatibility**: Target watchOS 11.2+ as specified in CLAUDE.md
