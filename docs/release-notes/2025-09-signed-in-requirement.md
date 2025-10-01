# Release Notes — iOS Signed-In Requirement

## Highlights
- The iPhone app now requires a Supabase account to access matches, schedules, trends, and team management.
- Apple Watch continues to run matches offline; pending data automatically syncs once the phone signs in.
- Logout now clears local caches so the next user starts from a clean slate.

## Authentication & Onboarding
- Removed the "Continue without account" affordance across welcome, sign-in, and settings flows.
- Added a signed-out gate that blocks the tab interface until Supabase authentication succeeds.
- Clarified copy that iOS is the authenticated hub while the watch remains local-first.

## Sync & Persistence
- SwiftData stores require a live `ownerId` before saving. Legacy JSON fallback paths have been deleted.
- Watch connectivity now defers payloads until the phone signs in, emitting telemetry breadcrumbs when snapshots queue or flush.
- Logging out wipes match history, schedules, journals, and team caches.

## Testing
- Added unit coverage for watch-to-phone sync queueing and logout wipes.
- Added a UITest to ensure the signed-out gate renders when no session exists.

## Upgrade Notes
- Install the update on the iPhone first, sign in with Supabase credentials, then open the watch app to flush any pending matches.
- If you previously relied on offline iPhone mode, sign in to retain access to existing matches and schedules.
