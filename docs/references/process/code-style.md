# Code Style Reference

## General
- Swift + SwiftUI with 2-space indentation.
- Match filename to the primary type (`TimerView.swift`, `MatchSetupViewModel.swift`).
- Organize with `// MARK:` sections when files contain multiple logical areas.
- Prefer protocols for platform abstractions (e.g., `HapticsProviding`).

## Naming
- Types: `PascalCase`.
- Functions/properties: `camelCase`.
- View types suffixed with `View`; ViewModels with `ViewModel`; services with `Service`.

## SwiftUI Patterns
- Keep views declarative; move logic into ViewModels/services.
- Use `@StateObject` for long-lived models, `@ObservedObject` for transient ones.
- Inject dependencies through initializers to aid previews/tests.

## Documentation
- Add DocC comments to public types and complex functions.
- Keep inline comments minimal—only where the intent is not immediately obvious.

## Optional Tooling
- SwiftFormat / SwiftLint configs can be run locally before PRs.
- Avoid committing formatter diffs unrelated to your change.
