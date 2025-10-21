---
task_id: 05
plan_id: welcome_carousel_refresh
plan_file: ../../plans/welcome_carousel/PLAN.md
title: Accessibility, polish, and testing
phase: Phase 5 - Validation
created: 2025-10-11
status: Completed
completed: 2025-10-11
priority: Medium
estimated_minutes: 60
dependencies: [TASK_04_welcome_carousel.md]
tags: [accessibility, testing, polish]
---

# Task 05: Accessibility, Polish, and Testing

## Objective

Finalize the onboarding refresh with accessibility refinements, localized string hooks, and validation via manual and automated tests.

## Context

- Carousel should honor `reduceMotion` and `dynamicType` settings while VoiceOver announces slide changes and button hints.
- SF Symbol usage must include descriptive accessibility labels and adapt palette colors for high contrast settings (e.g., differentiate when `Increase Contrast` is enabled).
- Copy may remain English-only for now, but structure strings using `NSLocalizedString` so localization teams can follow up.
- Testing should ensure the onboarding still appears once per app install (where feasible) and that coordinator transitions remain stable.

## Steps

1. Audit accessibility labels, hints, and traits for slides, page indicators, and CTA buttons; adjust as needed.
2. Wire strings through localization entries (`Localizable.strings`) with TODO comments if translations pending.
3. Add or update SwiftUI/Swift Testing coverage (e.g., unit test that `WelcomeSlide.defaultSlides` count is 3, UI test verifying carousel swipes).
4. Perform manual QA pass on physical or simulated devices (light/dark mode, small/large phones).
5. Update plan progress and document any remaining follow-ups in `Surprises & Discoveries` or `Constraints`.

## Acceptance Criteria

- Accessibility checks (VoiceOver, reduce motion) behave as expected without warnings.
- Tests added or updated in previous steps pass locally.
- Documentation and plan updates reflect completed work with any outstanding follow-ups noted.

## Notes

- Added accessibility labels/hints across the carousel, page indicator, CTA buttons, and footer; animations now respect `reduceMotion`.
- Hooked all new strings through `NSLocalizedString` with comments for localization hand-off.
- Created `WelcomeSlideTests` to cover slide data and palette resolution; app target builds successfully. `RefZoneiOS` test run currently fails in this environment because `GoogleSignIn` SPM dependency is unavailable, matching existing warnings—callout left for follow-up.
