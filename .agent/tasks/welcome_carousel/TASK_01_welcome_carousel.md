---
task_id: 01
plan_id: welcome_carousel_refresh
plan_file: ../../plans/welcome_carousel/PLAN.md
title: Select SF Symbols for onboarding slides
phase: Phase 1 - Iconography & Content
created: 2025-10-11
status: Completed
completed: 2025-10-11
priority: High
estimated_minutes: 45
dependencies: []
tags: [ios, sf-symbols, onboarding]
---

# Task 01: Select SF Symbols for Onboarding Slides

## Objective

Choose a cohesive set of SF Symbols that convey the watch, iPhone, and web experiences, define their rendering configuration (weight, scale, palette colors), and document guidance for consistent usage in the carousel.

## Context

- Symbols must be available on our minimum deployment target (verify iOS 17 availability; prefer symbols shipped in iOS 15+ to maximize compatibility).
- Consider multi-color palette rendering to align with theme accents (`accentPrimary`, `accentSecondary`, `accentMuted`) while remaining accessible in light/dark mode.
- The symbol identifiers will be stored on `WelcomeSlide` instances and used by `OnboardingCardView`.

## Steps

1. Audit SF Symbols app (or reference documentation) to shortlist 2–3 candidates per slide theme (watch usage, mobile insights, collaborative web dashboard).
2. Validate availability using `UIImage(systemName:)` tests or SF Symbols metadata for the current deployment target.
3. Select final symbol for each slide and decide on scale (e.g., `.large`) and rendering mode (`hierarchical`, `palette`, or `monochrome`).
4. Document the chosen symbols, recommended colors from the theme palette, and accessibility labels in task notes for downstream implementation.

## Acceptance Criteria

- Three SF Symbol names are selected and validated for platform availability.
- Styling guidance (rendering mode, primary/secondary colors) is captured for each symbol.
- Notes include suggested accessibility descriptions matching slide copy.

## Notes

- **Slide 1 – Watch match control**: `applewatch`, prefers `symbolRenderingMode = .palette`, using `theme.colors.accentSecondary` (foreground) plus `theme.colors.accentMuted` (secondary). Accessibility label: “Apple Watch showing live match timer.”
- **Slide 2 – iPhone insights**: `iphone.gen3`, rendered with `.palette`, pairing `theme.colors.accentPrimary` with `theme.colors.textSecondary`. Accessibility label: “iPhone displaying officiating insights.”
- **Slide 3 – Web collaboration**: `macbook.and.iphone`, rendered with `.palette`, blending `theme.colors.accentSecondary` and `theme.colors.accentPrimary` for dual-device emphasis. Accessibility label: “MacBook and iPhone illustrating synced dashboards.”
- Availability verified via `NSImage(systemSymbolName:accessibilityDescription:)` on the local toolchain; all three resolve successfully.
