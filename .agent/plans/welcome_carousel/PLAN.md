---
plan_id: welcome_carousel_refresh
title: Welcome Onboarding Refresh Plan
created: 2025-10-11
updated: 2025-10-11
status: Completed
total_tasks: 5
completed_tasks: 5
priority: High
tags: [ios, onboarding, swiftui, authentication, design-system]
---

# Welcome Onboarding Refresh Plan

## Purpose / Big Picture

Deliver a three-slide onboarding carousel inside `RefZoneiOS/Features/Authentication/Views/WelcomeView.swift` that aligns with the latest cross-platform design, highlights watch/iPhone/web value propositions, and keeps sign-in/create-account flows owned by `AuthenticationCoordinator`. Once complete, new users will see polished, themed onboarding slides with SF Symbol-based iconography before selecting their auth path.

## Surprises & Discoveries

- RefZoneiOS tests cannot currently run in this environment because the `GoogleSignIn` Swift Package dependency is missing; highlighted in Task 05 notes for follow-up.

## Decision Log

- (2025-10-11) Locked onboarding iconography: `applewatch`, `iphone.gen3`, and `macbook.and.iphone` rendered with palette colors from the theme.

## Outcomes & Retrospective

- To be completed after execution.

## Context and Orientation

- `RefZoneiOS/Features/Authentication/Views/WelcomeView.swift` currently renders a static single-screen welcome with system symbols and text blocks.
- `RefZoneiOS/Features/Authentication/Coordinators/AuthenticationCoordinator.swift` presents the welcome flow once, owns sign-in/up transitions, and should keep that responsibility.
- The shared theme system injects colors and typography with `@Environment(\.theme)`. Any new slides must consume palette tokens rather than hard-coded values.
- The refreshed design relies on consistent iconography; we will lean on SF Symbols (e.g., `applewatch`, `iphone.gen3`, `macbook.and.ipad`) instead of bespoke illustration assets to keep delivery lightweight while matching the platform aesthetic.
- No existing carousel helper exists; we will build a SwiftUI `TabView`-based or custom paging component with dot indicators matching brand styling.

## Plan of Work

1. **Iconography selection**: Audit available SF Symbols, choose variants that best represent watch, iPhone, and web touchpoints, and document styling guidelines (weight, rendering mode, color) for consistent usage across the carousel.
2. **Model scaffolding**: Introduce a lightweight `WelcomeSlide` model (likely in `RefZoneiOS/Features/Authentication/Models/WelcomeSlide.swift`) encapsulating title, subtitle, symbol name, and accessibility metadata. Provide static factory data describing the three slides so views remain declarative.
3. **Component construction**: Create reusable SwiftUI building blocks under `RefZoneiOS/Features/Authentication/Views/Components/`:
   - `OnboardingCardView` that consumes a `WelcomeSlide`.
   - `OnboardingPageIndicator` to render themed dot indicators with animation support.
   - Ensure components read theme values, support Dynamic Type, and apply VoiceOver labels.
4. **View integration**: Refactor `WelcomeView` to use the new carousel. Manage paging state via `@State` and adopt `TabView` with `tabViewStyle(.page)` (or custom if design requires). Retain coordinator buttons, update layout padding, and apply subtle animations (slide transitions, fade on change) aligned with design.
5. **Coordinator wiring & gating**: Confirm `AuthenticationCoordinator` still sets `hasCompletedOnboarding` only after auth entry points, and ensure the refreshed view exposes callbacks without altering coordinator interface. Update previews and add unit/UI tests if feasible (e.g., snapshot of slide data, verify slide count).

## Concrete Steps

Corresponding task files live in `.agent/tasks/welcome_carousel/` and detail each workstream.

## Progress

- [x] (TASK_01_welcome_carousel.md) (2025-10-11) SF Symbol selection & styling guide
- [x] (TASK_02_welcome_carousel.md) (2025-10-11) WelcomeSlide data model scaffolding
- [x] (TASK_03_welcome_carousel.md) (2025-10-11) Carousel component implementation
- [x] (TASK_04_welcome_carousel.md) (2025-10-11) WelcomeView refactor & coordinator hooks
- [x] (TASK_05_welcome_carousel.md) (2025-10-11) Accessibility, polish, and verification

## Testing Approach

- Add SwiftUI preview snapshot verification or Swift Testing snapshot (if framework available) for the new carousel layout.
- Expand existing authentication flow tests (if present) or add a lightweight view model test validating slide data ordering.
- Perform manual testing on iPhone simulators across light/dark mode, Dynamic Type, and VoiceOver to ensure carousel and buttons work as expected.

## Constraints & Considerations

- Maintain MVVM separation: keep business state in the coordinator while the view remains declarative.
- Animation style, localization requirements for slide copy, and whether SF Symbols should use variable color remain open questions with design—capture assumptions before implementation.
- Need confirmation on copy localization timeline; plan assumes English strings added to `Localizable.strings` once provided.
- Ensure the carousel respects accessibility (prefers reduced motion, VoiceOver order) and theme contrast ratios.

## Next Steps

1. Restore the GoogleSignIn package (or stub the dependency) so the RefZoneiOS tests can run end-to-end.
2. Give the carousel a manual accessibility pass (VoiceOver + Reduce Motion) on device/simulator once the dependency issue is resolved.
