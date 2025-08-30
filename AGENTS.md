# Repository Guidelines

## Project Structure & Module Organization
- `RefWatch Watch App/App`: App entry (`RefWatchApp.swift`, `ContentView.swift`).
- `RefWatch Watch App/Core`: Reusable UI components and services (e.g., `TimerService`, `MatchStateService`).
- `RefWatch Watch App/Features`: Feature-first MVVM folders (`MatchSetup`, `Match`, `Events`, `Timer`, `Settings`, `TeamManagement`) with `Views/Models/ViewModels`.
- `RefWatch Watch App/Assets.xcassets` and `Preview Content`: Visual assets and SwiftUI previews.
- Tests: `RefWatch Watch AppTests` (unit) and `RefWatch Watch AppUITests` (UI).

## Build, Test, and Development Commands
- Open in Xcode: `open RefWatch.xcodeproj` (or double-click the project).
- Build (CLI): `xcodebuild -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`.
- Test (CLI): `xcodebuild test -project RefWatch.xcodeproj -scheme "RefWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`.
- Run locally: Select the "RefWatch Watch App" scheme in Xcode and an Apple Watch simulator, then Run.
- Share the scheme for CLI/CI: Product → Scheme → Manage Schemes… → check "Shared".

## Coding Style & Naming Conventions
- Swift + SwiftUI, MVVM. Use 2-space indentation and keep files focused.
- Names: Types `PascalCase`; functions/properties `camelCase`.
- Suffixes: views end with `View`, view models with `ViewModel`, services with `Service`.
- One primary type per file; filename matches the type.
- Organize with `// MARK:` sections. No enforced linter; if you use SwiftFormat/SwiftLint locally, run before PRs.

## Testing Guidelines
- Framework: XCTest (unit and UI).
- Location: unit tests in `RefWatch Watch AppTests`, UI tests in `RefWatch Watch AppUITests`.
- Naming: `test<Action>_when<Context>_does<Outcome>()` (clear, behavior-driven).
- Focus: prioritize ViewModel and service tests; cover key flows with UI tests.
- Run: same `xcodebuild test` command as above or via Xcode.

## Commit & Pull Request Guidelines
- Commits: imperative, concise, single-purpose (e.g., "Improve timer pause logic", "Fix: goal recording flow").
- PRs: include a clear description, screenshots/GIFs for UI changes, test steps, and linked issues.
- Pre-submit: ensure the app builds, tests pass, and the changed flows run on a watch simulator.

## Security & Configuration Tips
- Do not commit secrets or personal `xcuserdata`. Share Xcode schemes so others can build/test.
- Repo includes Claude Code workflows; PRs may receive automated review comments.

