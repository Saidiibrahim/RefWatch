# Match Timer Architecture

Understand how the timer system orchestrates match, period, and penalty time while remaining platform-agnostic.

## Overview
The watch timer centers around ``TimerManager``, which coordinates clock updates and publishes state to faces implementing ``TimerFaceModel``. Configuration flows from the match setup feature and persists via ``MatchHistoryService``.

## Key Types
- ``TimerManager``: Controls the main and period timers, handles halftime.
- ``TimerFaceModel``: Protocol exposing read-only timer state and actions like `pauseMatch()` and `resumeMatch()`.
- ``TimerFaceStyle``: Enumerates available faces, persisted with `@AppStorage("timer_face_style")`.
- ``TimerFaceFactory``: Builds SwiftUI views for a selected face.

## Data Flow
1. Match configuration originates in ``MatchSetupViewModel``.
2. ``TimerManager`` receives configuration and starts the match timer.
3. Faces observe state via combine publishers and update UI in ``TimerView``.
4. Completed matches persist through ``MatchHistoryService`` for later reference.

## Extending Timer Faces
- Add a new case to ``TimerFaceStyle`` and implement the drawing logic in a new view.
- Update ``TimerFaceFactory`` to return the new face.
- Conform to ``TimerFaceModel`` for any ViewModel powering the face.

Continue with the <doc:BuildCustomTimerFace> tutorial to implement a new face end-to-end.
