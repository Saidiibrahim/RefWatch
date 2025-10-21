---
task_id: 04
plan_id: welcome_carousel_refresh
plan_file: ../../plans/welcome_carousel/PLAN.md
title: Refactor WelcomeView to new carousel
phase: Phase 4 - Integration
created: 2025-10-11
status: Completed
completed: 2025-10-11
priority: High
estimated_minutes: 90
dependencies: [TASK_03_welcome_carousel.md]
tags: [welcome-view, swiftui, integration]
---

# Task 04: Refactor WelcomeView to New Carousel

## Objective

Replace the static welcome layout with the new carousel experience while preserving coordinator-driven authentication actions and overall onboarding gating.

## Context

- `WelcomeView` currently uses a `ScrollView` with static content. The refactor should introduce a `TabView` or custom pager for the slides and adjust layout to match design (e.g., top hero, dot indicators, CTA buttons).
- Slides must surface the SF Symbols chosen in Task 01 with consistent sizing and palette-based coloring, adapting to light/dark modes.
- Coordinator methods `showSignIn()` and `showSignUp()` must remain reachable with existing analytics hooks.
- Need to ensure the view respects safe area, background colors, and theme spacing tokens.

## Steps

1. Inject slide data (`let slides = WelcomeSlide.defaultSlides(theme: theme)`) and manage the current index via `@State`.
2. Render the carousel using the new components, applying the SF Symbol styling guidance, and adding page indicators and animation (e.g., `withAnimation(.spring(response: ...))`).
3. Update CTA button styling to match design (primary/secondary) and align layout with new spacing.
4. Verify compatibility with `AuthenticationCoordinator` preview and ensure `hasCompletedOnboarding` behavior unaffected.

## Acceptance Criteria

- Welcome view displays three slides that can be swiped horizontally with page indicators updating accordingly.
- Sign-in and create-account buttons function exactly as before.
- Layout adheres to design spacing across common device sizes (iPhone SE through Pro Max).

## Notes

- Replaced static welcome layout with `TabView`-backed carousel driven by `WelcomeSlide.defaultSlides(theme:)` and the new components.
- Added safe indexing plus Dynamic Type-aware padding/height adjustments, ensuring vertical scrolling accommodates accessibility sizes.
- CTA buttons keep existing coordinator calls while strings now route through `NSLocalizedString` for future localization.
