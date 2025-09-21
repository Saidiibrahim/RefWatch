# Plan: Restore Quick-Return Pill for Match Runtime

## Summary
- **Owner**: Ibby (handoff documented by Codex)
- **Last Updated**: 2025-09-19
- **Status**: Pending implementation
- **Goal**: Make sure an active match holds a `WKExtendedRuntimeSession` so the watchOS lock-screen pill appears reliably during quick return.

## Problem Statement
The current watchOS build fails to keep the quick-return pill alive when the display locks. Logs show the extended runtime request is rejected (`client not approved`), leaving the session in the `.invalid` state.

## Investigation Notes
- Runtime manager (`RefZoneWatchOS/Core/Services/Runtime/BackgroundRuntimeSessionController.swift`) correctly requests a session whenever a match starts or resumes.
- App Info plist (`RefZoneWatchOS/App/RefZoneWatchApp-Info.plist`) includes `WKBackgroundModes = ["workout-processing"]` as required.
- Watch target points to `RefZone Watch App.entitlements` in project settings.
- Built binary that reproduced the issue did not have the entitlement signed in; the OS denied the session and terminated the process (`Error Domain=com.apple.CarouselServices.SessionErrorDomain Code=8 "client not approved"`).
- Delegate callbacks never fire because the session never transitions out of `.invalid`.

## Root Cause
The installed watch build was missing the `com.apple.developer.watchkit.background-mode` entitlement at runtime. Without that capability, watchOS rejects any extended runtime request with `client not approved`, preventing the quick-return pill from appearing.

## Action Items
1. **Verify signing pipeline**
   - Confirm Debug/Release configurations on the watch target include `RefZone Watch App.entitlements`.
   - Re-run `codesign -d --entitlements :- "RefZone Watch App.app"` on the built product to ensure the entitlement is present.
2. **Provisioning profile check**
   - Make sure the provisioning profile used on device grants the Workout Processing background mode capability.
3. **Reinstall + test**
   - Build and install on a physical watch (preferred) or simulator; start a match, lock the screen, and confirm the quick-return pill appears.
4. **Regression QA**
   - Exercise pause/resume, halftime, extra time, and match completion flows to ensure the runtime controller restarts sessions as expected.

## Verification
- `codesign` output contains:
  - `com.apple.developer.watchkit.background-mode` -> `[ workout-processing ]`
- Console logs show `WKExtendedRuntimeSession` transitioning to `state == running`.
- Lock-screen pill stays visible during active match.

## Risks / Follow-ups
- Physical device testing is required; simulator may not surface entitlement mismatches.
- If future changes introduce additional background modes, keep the DEBUG assertion in `BackgroundRuntimeSessionController` to surface missing configuration early.

