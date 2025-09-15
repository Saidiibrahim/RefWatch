# AGENTS.md

## Scope
Cross‑cutting iOS building blocks under `Core/`: DesignSystem, Platform, Persistence, Diagnostics, etc.

## Modules
- DesignSystem: Theme and shared styling primitives. No business logic.
- Platform: iOS adapters (haptics, connectivity, AI). Conform to protocols; keep thin.
- Persistence: SwiftData stores and in‑memory variants. Do not couple to views.
- Diagnostics: Logging and debug helpers; avoid leaking into release logic.

## Conventions
- Protocol‑first; inject adapters/services into view models and screens.
- Keep code iOS‑specific but portable—avoid watch‑only imports.
- Single‑purpose files, 2‑space indentation, consistent naming (`View`, `ViewModel`, `Service`).

## Testing
- Prefer in‑memory stores and adapter mocks for unit tests. Keep tests deterministic.

