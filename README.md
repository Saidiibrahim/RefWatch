# RefZone Watch App

A WatchOS app designed for football/soccer referees to manage matches efficiently.

## Features

- **Match Timer Management**
  - Start/pause/resume match timing
  - Automatic period tracking
  - Half-time countdown
  - Extra time support

- **Match Events Recording**
  - Goals
  - Yellow/Red cards
  - Substitutions
  - Team-specific events

- **Match Configuration**
  - Customizable match duration
  - Adjustable number of periods
  - Half-time length settings
  - Extra time and penalties options

- **Match Library**
  - Save match configurations
  - Quick access to saved matches
  - Match history

## Account Requirement (iOS)

The iPhone app now requires a signed-in Supabase account. All match history, schedules, and team edits are linked to the authenticated user. Your Apple Watch can still run matches offline; once you sign in on the phone, pending data syncs automatically.

## Tech Stack

- Swift
- SwiftUI
- WatchOS
- MVVM Architecture

## Local Secrets (Debug only)

- The app reads `OPENAI_API_KEY` from the process environment in Debug builds only (see `RefZoneiOS/Core/Platform/AI/Secrets.swift`).
- Do not commit secrets to schemes or source. Options for local setup:
  - Add `OPENAI_API_KEY` to your user (unshared) Xcode scheme under Run → Arguments → Environment Variables.
  - Or export it in your shell before launching from Xcode: `export OPENAI_API_KEY=...`.
- A template exists at `RefZoneiOS/Config/Secrets.example.xcconfig` for team guidance; `Secrets.xcconfig` is gitignored.
