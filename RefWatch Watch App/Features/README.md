# Features Module

This module contains all the distinct functional areas of the RefWatch Watch App, organized by domain.

## Current Features

- **Events**: Handles match events like cards, goals, and substitutions
- **Match**: Core match management and timing functionality
- **MatchSetup**: Pre-match configuration and team setup
- **Settings**: App configuration and preferences
- **Timer**: Match timing and period management

## Structure

Each feature follows a consistent organization:

- `Models/`: Data structures and business objects
- `ViewModels/`: Business logic and state management
- `Views/`: UI components specific to the feature

## Guidelines

- Each feature should be self-contained and independent
- Shared functionality should be moved to the Core module
- Features can depend on Core but should not depend on other features
