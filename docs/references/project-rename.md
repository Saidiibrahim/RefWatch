# Project Rename: RefZone → RefWatch

This document details the comprehensive rename of the project from "RefZone" to "RefWatch" completed on December 27, 2025.

## Overview

The project was renamed to align with the intended public release name "RefWatch". This involved renaming directories, files, bundle identifiers, app groups, URL schemes, and updating all code references.

---

## Directories Renamed

| Original | New |
|----------|-----|
| `RefZone.xcodeproj` | `RefWatch.xcodeproj` |
| `RefZoneWatchOS/` | `RefWatchWatchOS/` |
| `RefZoneiOS/` | `RefWatchiOS/` |
| `RefZoneWidgets/` | `RefWatchWidgets/` |
| `RefZoneWatchOSTests/` | `RefWatchWatchOSTests/` |
| `RefZoneiOSTests/` | `RefWatchiOSTests/` |
| `RefZoneWatchOSUITests/` | `RefWatchWatchOSUITests/` |
| `RefZoneiOSUITests/` | `RefWatchiOSUITests/` |
| `Documentation/RefZone.docc/` | `Documentation/RefWatch.docc/` |

---

## Files Renamed

| Original | New |
|----------|-----|
| `RefZone Watch App.entitlements` | `RefWatch Watch App.entitlements` |
| `RefZoneWidgetsExtension.entitlements` | `RefWatchWidgetsExtension.entitlements` |
| `RefZoneiOS/RefZoneiOS.entitlements` | `RefWatchiOS/RefWatchiOS.entitlements` |
| `RefZoneWatchOS/App/RefZoneApp.swift` | `RefWatchWatchOS/App/RefWatchApp.swift` |
| `RefZoneWatchOS/App/RefZoneWatchApp-Info.plist` | `RefWatchWatchOS/App/RefWatchWatchApp-Info.plist` |
| `RefZoneiOS/App/RefZoneiOSApp.swift` | `RefWatchiOS/App/RefWatchiOSApp.swift` |
| `RefZoneWidgets/RefZoneWidgets.swift` | `RefWatchWidgets/RefWatchWidgets.swift` |
| `RefZoneWidgets/RefZoneWidgetsBundle.swift` | `RefWatchWidgets/RefWatchWidgetsBundle.swift` |
| `Documentation/RefZone.docc/RefZone.md` | `Documentation/RefWatch.docc/RefWatch.md` |

### Scheme Files

| Original | New |
|----------|-----|
| `RefZone Watch App.xcscheme` | `RefWatch Watch App.xcscheme` |
| `RefZoneiOS.xcscheme` | `RefWatchiOS.xcscheme` |
| `RefZoneWidgetsExtension.xcscheme` | `RefWatchWidgetsExtension.xcscheme` |

---

## Bundle Identifiers

| Original | New |
|----------|-----|
| `com.IbrahimSaidi.RefZone.watchkitapp` | `com.IbrahimSaidi.RefWatch.watchkitapp` |
| `com.IbrahimSaidi.RefZone` | `com.IbrahimSaidi.RefWatch` |
| `com.IbrahimSaidi.RefZone.watchkitapp.RefZoneWidgets` | `com.IbrahimSaidi.RefWatch.watchkitapp.RefWatchWidgets` |
| `com.IbrahimSaidi.RefZone-Watch-AppTests` | `com.IbrahimSaidi.RefWatch-Watch-AppTests` |
| `com.IbrahimSaidi.RefZone-Watch-AppUITests` | `com.IbrahimSaidi.RefWatch-Watch-AppUITests` |
| `com.IbrahimSaidi.RefZoneiOSTests` | `com.IbrahimSaidi.RefWatchiOSTests` |
| `com.IbrahimSaidi.RefZoneiOSUITests` | `com.IbrahimSaidi.RefWatchiOSUITests` |

---

## App Group

| Original | New |
|----------|-----|
| `group.refzone.shared` | `group.refwatch.shared` |

Updated in:
- `RefWatch Watch App.entitlements`
- `RefWatchWidgetsExtension.entitlements`
- `RefWatchWatchOS/Core/Services/LiveActivity/LiveActivityStateStore.swift`

---

## URL Scheme

| Original | New |
|----------|-----|
| `refzone://` | `refwatch://` |

Updated in:
- `RefWatchWatchOS/App/RefWatchWatchApp-Info.plist`
- `RefWatchWidgets/RefWatchWidgets.swift`
- `RefWatchWidgets/AppIntents/MatchControlIntents.swift`

---

## Swift Code Changes

### App Entry Points

| File | Change |
|------|--------|
| `RefWatchWatchOS/App/RefWatchApp.swift` | `RefZone_Watch_AppApp` → `RefWatch_Watch_AppApp` |
| `RefWatchiOS/App/RefWatchiOSApp.swift` | `RefZoneiOSApp` → `RefWatchiOSApp` |

### Widget Code

| File | Change |
|------|--------|
| `RefWatchWidgets/RefWatchWidgets.swift` | Struct `RefZoneWidgets` → `RefWatchWidgets`, kind constant, display name |
| `RefWatchWidgets/RefWatchWidgetsBundle.swift` | Struct and references updated |

### Test Imports

All test files updated:
- WatchOS tests: `@testable import RefZone_Watch_App` → `@testable import RefWatch_Watch_App`
- iOS tests: `@testable import RefZoneiOS` → `@testable import RefWatchiOS`

### Logger Subsystems

| File | Change |
|------|--------|
| `RefWatchiOS/Core/Platform/Connectivity/AggregateDeltaCoordinator.swift` | `"RefZoneiOS"` → `"RefWatchiOS"` |
| `RefWatchWatchOS/Core/Platform/Connectivity/WatchAggregateSyncCoordinator.swift` | `"RefZoneWatchOS"` → `"RefWatchWatchOS"` |

---

## Info.plist Updates

### WatchOS (`RefWatchWatchApp-Info.plist`)
- `CFBundleDisplayName`: `RefZone` → `RefWatch`
- `CFBundleURLName`: `refzone` → `refwatch`
- `CFBundleURLSchemes`: `refzone` → `refwatch`
- `WKCompanionAppBundleIdentifier`: `com.IbrahimSaidi.RefZone` → `com.IbrahimSaidi.RefWatch`
- All usage descriptions updated

### iOS (`Info.plist`)
- All usage descriptions updated from "RefZone" to "RefWatch"

---

## Documentation Updated

- `CLAUDE.md` - Build commands, bundle ID references
- `README.md` - Project name, file paths
- `Documentation/RefWatch.docc/RefWatch.md` - Title and metadata
- Various `AGENTS.md` files throughout the project

---

## Build Verification

Both targets build successfully:

```bash
# WatchOS
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' build
# Result: BUILD SUCCEEDED

# iOS
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatchiOS" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
# Result: BUILD SUCCEEDED
```

---

## Post-Rename Tasks (Manual)

### Apple Developer Portal
1. Create new App IDs:
   - `com.IbrahimSaidi.RefWatch.watchkitapp`
   - `com.IbrahimSaidi.RefWatch`
   - `com.IbrahimSaidi.RefWatch.watchkitapp.RefWatchWidgets`
2. Create new App Group: `group.refwatch.shared`
3. Generate new provisioning profiles for all targets

### Google Sign-In
1. Update the bundle ID in [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Update `GID_CLIENT_ID` and `GID_REVERSED_CLIENT_ID` in `Secrets.xcconfig` if needed

### CI/CD
Update any CI/CD configurations that reference the old scheme or bundle names.

---

## Files Not Changed

The following were intentionally left unchanged:
- Git history - Preserved for reference
- Local Swift packages (`RefWatchCore`, `RefWorkoutCore`) - Already using correct naming
