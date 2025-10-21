---
task_id: 02
plan_id: welcome_carousel_refresh
plan_file: ../../plans/welcome_carousel/PLAN.md
title: Define WelcomeSlide model & sample data
phase: Phase 2 - Data Model
created: 2025-10-11
status: Completed
completed: 2025-10-11
priority: High
estimated_minutes: 40
dependencies: [TASK_01_welcome_carousel.md]
tags: [model, swift, onboarding]
---

# Task 02: Define WelcomeSlide Model & Sample Data

## Objective

Create a lightweight data model describing each onboarding slide and expose static sample data the SwiftUI views can iterate over.

## Context

- Model should live within the authentication feature scope, e.g., `RefZoneiOS/Features/Authentication/Models/WelcomeSlide.swift`.
- Properties include: `id`, `title`, `subtitle`, `symbolName`, optional `symbolRenderingMode`, `accentColors`, `accessibilityLabel`, and `analyticsIdentifier` if required later.
- Static `WelcomeSlide.defaultSlides(theme:)` helper (or similar) will centralize content while allowing for future localization.

## Steps

1. Add the new model file and declare a `struct WelcomeSlide: Identifiable, Hashable`.
2. Provide static factory function returning the three configured slides with localized strings placeholder and symbol metadata from Task 01.
3. Document intended usage with doc comments and mark TODO for localization if copy not yet in `Localizable.strings`.
4. Write lightweight unit test (if feasible) verifying slide count and unique identifiers.

## Acceptance Criteria

- Model compiles, conforms to `Identifiable`, and exposes slide + symbol metadata.
- Static factory returns three slides referencing the chosen SF Symbol names.
- Tests (if added) pass locally; otherwise, include preview validation to ensure data resolves.

## Notes

- Added `WelcomeSlide` with palette token indirection so components can resolve themed colors without hard-coding values.
- Implemented `defaultSlides(theme:)` returning watch, iPhone, and web experiences with placeholder localized strings and analytics identifiers.
- New `WelcomeSlideTests` verifies slide uniqueness, symbol names, and palette resolution behavior.
