---
task_id: 03
plan_id: welcome_carousel_refresh
plan_file: ../../plans/welcome_carousel/PLAN.md
title: Build carousel components
phase: Phase 3 - UI Components
created: 2025-10-11
status: Completed
completed: 2025-10-11
priority: High
estimated_minutes: 75
dependencies: [TASK_01_welcome_carousel.md, TASK_02_welcome_carousel.md]
tags: [swiftui, components, design-system]
---

# Task 03: Build Carousel Components

## Objective

Implement reusable SwiftUI components that render onboarding slides and paging indicators with proper theming and accessibility support.

## Context

- Components will live in `RefZoneiOS/Features/Authentication/Views/Components/`.
- `OnboardingCardView` should take a `WelcomeSlide` and lay out the large SF Symbol, title, and subtitle according to design spacing while respecting Dynamic Type and color scheme.
- `OnboardingPageIndicator` will display dot indicators with animated transitions and `UIAccessibility` labels indicating current slide position.

## Steps

1. Create `OnboardingCardView.swift` rendering slide content with responsive layout (e.g., using `GeometryReader` for symbol sizing if needed) and applying the rendering mode/colors defined in Task 01.
2. Implement `OnboardingPageIndicator.swift` that accepts total count and current index; support reduced motion and theme-aware colors.
3. Add preview configurations for light/dark, large text, and VoiceOver rotor hints.
4. Ensure both components expose minimal public API and rely on dependency injection for theme (via environment).

## Acceptance Criteria

- Components compile and integrate with theme environment without hard-coded colors.
- Previews demonstrate three slides with correct typography and spacing.
- Page indicator includes `accessibilityLabel` like "Slide 1 of 3" and respects reduced motion settings.

## Notes

- Added `OnboardingCardView` that reads theme spacing/typography, resolves palette colors from `WelcomeSlide`, and adapts icon sizing for Dynamic Type.
- Implemented `OnboardingPageIndicator` with spring animation gated by `reduceMotion`, accessible position announcements, and theme-aware colors.
- Introduced internal `ForegroundPaletteModifier` helper to render palette symbols with up to four colors.
