# App Module

This module serves as the entry point and root configuration of the RefWatch Watch App.

## Purpose

- Contains the app's entry point (`RefWatchApp.swift`)
- Manages root-level navigation and initial view setup (`AppRootView.swift`, `MatchRootView.swift`)
- Houses app-wide configuration and initialization logic

## Key Components

- `RefWatchApp.swift`: The main app delegate and entry point
- `AppRootView.swift`: Hosts the Match root flow
- `MatchRootView.swift`: The root view for the Match experience

## Guidelines

- Keep this module focused on app-level concerns
- Avoid placing business logic or feature-specific code here
- Use this layer for app-wide dependency injection and configuration
