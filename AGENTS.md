# Repository Guidelines

## Project Structure & Module Organization
- watchOS (primary)
  - `RefZoneWatchOS/App`: App entry (`RefWatchApp.swift`, `ContentView.swift`).
  - `RefZoneWatchOS/Core`: Reusable components and services (`TimerManager`, `MatchHistoryService`, `PenaltyManager`, protocols, platform adapters like `WatchHaptics`).
  - `RefZoneWatchOS/Features`: Feature-first MVVM folders (`MatchSetup`, `Match`, `Events`, `Timer`, `Settings`, `TeamManagement`) with `Views/Models/ViewModels`.
  - `RefZoneWatchOS/Assets.xcassets`, `Preview Content`.
  - Tests: `RefWatch Watch AppTests` (unit) and `RefWatch Watch AppUITests` (UI).

- iOS (complementary)
  - `RefZoneiOS/App`: App entry (`RefZoneiOSApp.swift`, `MainTabView.swift`, `AppRouter.swift`).
  - `RefZoneiOS/Core`: `DesignSystem/` (Theme), `Platform/` (iOS adapters such as `IOSHaptics`, `ConnectivityClient`).
  - `RefZoneiOS/Features`: Feature-first MVVM folders (`Matches`, `Live`, `Library`, `Trends`, `Settings`).
  - `RefZoneiOS/Assets.xcassets`.

- Shared (via Target Membership)
  - Domain models under `RefZoneWatchOS/Features/**/Models`.
  - Services under `RefZoneWatchOS/Core/Services`.
  - Protocols under `RefZoneWatchOS/Core/Protocols`.

## Build, Test, and Development Commands
- Open in Xcode: `open RefZone.xcodeproj` (or double‑click the project).
- Build (watchOS, CLI): `xcodebuild -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`.
- Build (iOS, CLI): `xcodebuild -project RefZone.xcodeproj -scheme RefZoneiOS -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Test (watchOS, CLI): `xcodebuild test -project RefZone.xcodeproj -scheme "RefZone Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`.
- Run locally: Select scheme → choose simulator → ⌘R.
- Share schemes for CLI/CI: Product → Scheme → Manage Schemes… → check "Shared".

## Coding Style & Naming Conventions
- Swift + SwiftUI, MVVM. Use 2-space indentation and keep files focused.
- Names: Types `PascalCase`; functions/properties `camelCase`.
- Suffixes: views end with `View`, view models with `ViewModel`, services with `Service`.
- One primary type per file; filename matches the type.
- Organize with `// MARK:` sections. No enforced linter; if you use SwiftFormat/SwiftLint locally, run before PRs.

## Testing Guidelines
- Framework: XCTest (unit and UI).
- Location: unit tests in `RefWatch Watch AppTests`, UI tests in `RefWatch Watch AppUITests` (iOS tests may be added later).
- Naming: `test<Action>_when<Context>_does<Outcome>()` (clear, behavior‑driven).
- Focus: prioritize ViewModel and service tests; cover key flows with UI tests.
- Run: use the test commands above or Xcode.

## Commit & Pull Request Guidelines
- Commits: imperative, concise, single-purpose (e.g., "Improve timer pause logic", "Fix: goal recording flow").
- PRs: include a clear description, screenshots/GIFs for UI changes, test steps, and linked issues.
- Pre-submit: ensure the app builds, tests pass, and the changed flows run on a watch simulator.

## Security & Configuration Tips
- Do not commit secrets or personal `xcuserdata`.
- Share Xcode schemes so others can build/test (both watchOS and iOS).
- Avoid importing `WatchKit` in iOS or shared sources; use adapters (`HapticsProviding`, etc.) and `#if os(watchOS)` for watch‑only code.
- Repo includes Claude Code workflows; PRs may receive automated review comments.

### Timer Faces (watchOS)
- `TimerFaceModel` protocols expose read‑only state (`matchTime`, `periodTimeRemaining`, etc.) and minimal actions (`pauseMatch`, `resumeMatch`, `startHalfTimeManually`).
- `TimerFaceStyle` enumerates available faces; default is `standard`. Persisted via `@AppStorage("timer_face_style")`.
- `TimerFaceFactory` returns a SwiftUI view for a given style and model.
- `StandardTimerFace` mirrors the previous inline timer UI.
- `TimerView` is now the host: keeps period label, score display, actions sheet, and lifecycle routing; renders the selected face in the middle.
