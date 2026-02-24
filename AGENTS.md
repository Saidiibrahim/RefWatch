# Repository Guidelines

## Project Overview

RefZone is a multi-platform app (watchOS + iOS + Web) designed for football/soccer referees to manage matches efficiently. The watchos app is designed for referees to use during matches and other workout activities. The iOS and web apps are designed to complement the watchos app and provide a more comprehensive experience. Even though the iOS app also allows referees to start matches and other workout activities, the watchos app is the primary app for referees. The iOS and web apps are designed to provide a more comprehensive experience for referees (e.g ai assistance, calendar, etc.).

 The codebase uses SwiftUI and follows MVVM with a feature‑first architecture and modern Swift patterns. The watchOS app is production‑first; the iOS app complements it with match library, live mirror, and post‑match views. Below are the main platforms and their relationship to the project.

- watchOS (in this codebase)
- iOS (in this codebase)
- web (not in this codebase; however it is relevant to the project)
- Both follow a feature-first architecture MVVM folders with Views/Models/ViewModels.

## Tech Stack

- SwiftUI
- Swift
- Swift Testing Framework (for testing)
- SwiftData
- Supabase
- Supabase Functions
- Supabase Auth
- Supabase Storage
- OpenAI Responses API
- Google Sign In
- Google Sign In Swift

## Build, Test, and Development Commands

You have access to the xcodeBuildMCP to build and test the project. Prefer this over manually building the project.


Common local workflows from repo docs/scripts:
```bash
# One-time local setup (generates RefWatchiOS/Config/Config.xcconfig)
./scripts/setup.sh

# Install git hooks (pre-commit secrets guard)
./scripts/install-git-hooks.sh

# Build watchOS app
xcodebuild -project RefWatch.xcodeproj \
  -scheme "RefWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build

# Build iOS companion app
xcodebuild -project RefWatch.xcodeproj \
  -scheme "RefWatchiOS" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Run watchOS tests
xcodebuild test -project RefWatch.xcodeproj \
  -scheme "RefWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

# iOS coverage run (auto-picks simulator)
./scripts/test-ios-coverage.sh

# Build docs
xcodebuild docbuild
```

## Coding Style & Naming Conventions

- Swift + SwiftUI, MVVM. Use 2-space indentation and keep files focused.
- Names: Types `PascalCase`; functions/properties `camelCase`.
- Suffixes: views end with `View`, view models with `ViewModel`, services with `Service`.
- One primary type per file; filename matches the type.
- Organize with `// MARK:` sections. No enforced linter; if you use SwiftFormat/SwiftLint locally, run before PRs.

## Important Tools Available to You

- xcodeBuildMCP: to build and test the project.
- supabaseMCP: to interact with the supabase database powering the project.
- context7 MCP: For access to the latest documentation. Useful for looking up SDK documentation and other documentation.

## Testing Guidelines

- Framework: Swift Testing Framework.
- Naming: `test<Action>_when<Context>_does<Outcome>()` (clear, behavior‑driven).
- Focus: prioritize ViewModel and service tests; cover key flows with UI tests.
- Run: use the xcodeBuildMCP to build and test the project.

## Security & Configuration Tips

- Do not commit secrets or personal `xcuserdata`.
- Share Xcode schemes so others can build/test (both watchOS and iOS).
- Avoid importing `WatchKit` in iOS or shared sources; use adapters (`HapticsProviding`, etc.) and `#if os(watchOS)` for watch‑only code.
- Repo includes Claude Code workflows; PRs may receive automated review comments.

## ExecPlans

When writing complex features or refactoring, you should create an ExecPlan as described in the .agent/plans/PLANS.md file. This plan should be stored in the `.agent/plans/{feature_name}/` directory and it should be accompanied by a task list in the `.agent/tasks/{feature_name}/` directory. Place any temporary research, clones, etc., in the .gitignored subdirectory of the .agent/ directory.