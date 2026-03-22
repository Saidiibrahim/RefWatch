# App Review Response – Match Mode Runtime Continuity

Draft to paste into App Store Connect’s Resolution Center when explaining the current watchOS implementation:

Hi,

RefWatch’s watch app is used by referees to time and manage a live match.

In the corrected build, the watch extension ships with `WKBackgroundModes = [workout-processing]` only. RefWatch does not use background audio, Apple Music, or media playback on Apple Watch.

For Match Mode, the app starts an `HKWorkoutSession` only while a match is unfinished. We made this change because Apple documents active workout sessions as the supported watchOS continuity path for an active long-running session and for relaunch recovery via `handleActiveWorkoutRecovery()`.

How Match Mode uses HealthKit:
• The workout configuration is `.other` and represents the unfinished officiating session.
• The workout session starts when an unfinished match begins and ends immediately when the match is completed, reset, or cancelled.
• Match Mode persists the referee’s unfinished match state locally so the app can restore the appropriate unfinished screen after relaunch, including halftime waiting, extra-time waiting, and penalties, when authorization and workout-session recovery conditions allow.
• Match Mode does not use HealthKit for live coaching, audio, Apple Music control, or media playback. Its purpose here is unfinished-match continuity for live officiating.

Important platform boundary:
• We understand that watchOS still allows explicit user dismissal/app switching and other system-driven interruptions.
• Our intent is supported continuity and relaunch recovery within watchOS workout-session semantics, not an unconditional foreground lock.

Requested outcome:
• Please review the corrected build with the understanding that the watch extension ships with `WKBackgroundModes = [workout-processing]` only, and that `HKWorkoutSession` is used solely to support unfinished officiating continuity and recovery on Apple Watch.

Thank you.
