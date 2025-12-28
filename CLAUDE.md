# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RefWatch is a multi-platform app (watchOS + iOS) designed for football/soccer referees to manage matches efficiently. The codebase uses SwiftUI and follows MVVM with a feature‑first architecture and modern Swift patterns. The watchOS app is production‑first; the iOS app complements it with match library, live mirror, and post‑match views.

## Build & Test Commands

### Building the Project
```bash
# Build the Watch app
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build

# Build the iOS app
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatchiOS" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build all targets (schemes must be shared)
xcodebuild -project RefWatch.xcodeproj build
```

### Running Tests
```bash
# Run watchOS unit tests
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' test

# (When present) Run iOS unit tests
xcodebuild -project RefWatch.xcodeproj -scheme "RefWatchiOS" -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Platform Considerations

- **watchOS**: target 11.2+, WatchKit haptics; avoid per‑tick logs; keep timer scheduling in `.common` and UI updates on main thread.
- **Development Team / Bundle IDs**: configured via `RefWatchiOS/Config/Config.xcconfig` (generate with `scripts/setup.sh`).
- **Interface Orientations**: Portrait and Portrait Upside Down
- **Deployment**: Watch-only app (WKWatchOnly = YES)

- **iOS**: complementary app with tabs (Matches, Live, Trends, Library, Settings). Uses platform adapters (e.g., `IOSHaptics`) and compiles shared models/services/ViewModels via target membership. Avoid importing `WatchKit` in shared or iOS code.

## ExecPlans

When writing complex features or refactoring, you should create an ExecPlan as described in the .agent/plans/PLANS.md file. This plan should be stored in the `.agent/plans/{feature_name}/` directory and it should be accompanied by a task list in the `.agent/tasks/{feature_name}/` directory. Place any temporary research, clones, etc., in the .gitignored subdirectory of the .agent/ directory.
