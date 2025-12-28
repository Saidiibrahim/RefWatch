# AGENTS.md

## Scope
Feature‑first MVVM code for the iOS app. Applies to `RefWatchiOS/Features/`.

## Structure
- Each feature is `FeatureName/{Models, ViewModels, Views}`.
- Views are SwiftUI. Business logic in ViewModels and services.
- Use `AppRouter` for navigation patterns shared across features.

## Conventions
- Reuse domain models/services shared with watchOS via target membership; guard platform differences with adapters.
- 2‑space indent, one primary type per file. Suffixes: `View`, `ViewModel`, `Service`.

## Testing
- Focus on ViewModels and iOS‑specific services. UI tests should target key tab flows (Matches, Live, Library, Trends, Settings).

