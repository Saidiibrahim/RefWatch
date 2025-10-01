# Runbook — iOS Supabase Auth Gate

## Purpose
Ensure the iPhone app requires an authenticated Supabase session, remove legacy ownerless persistence paths, and document how to recover if the auth gate must be bypassed after release.

## Pre-Flight Checklist
- [ ] Confirm watchOS pairing and local flows still function when the phone is signed out.
- [ ] Verify the Supabase project has the required tables, RLS policies, and stored procedures (run the Supabase MCP `supabase__doctor` if unsure).
- [ ] Make sure QA devices have Supabase credentials with production data access.
- [ ] Share the `RefZoneiOS` and `RefZone Watch App` schemes before building archives (`Product → Scheme → Manage Schemes… → Shared`).

## Removing Legacy Fallback Stores
1. Delete any lingering JSON payloads under `~/Library/Application Support/RefZone/` on QA devices (they are unused after Phase 3.)
2. Confirm `MatchHistoryService`, `TeamLibraryService`, and other JSON-based helpers have been removed from the project (they were replaced by the SwiftData stores).
3. Clean derived data (`xcodebuild -workspace RefZone.xcodeproj -scheme RefZoneiOS clean`) to guarantee SwiftData models regenerate.
4. Run targeted tests to verify SwiftData-only persistence:
   - `xcodebuild test -project RefZone.xcodeproj -scheme RefZoneiOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:RefZoneiOSTests/SwiftDataMatchHistoryStoreTests`
   - `xcodebuild test -project RefZone.xcodeproj -scheme RefZoneiOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:RefZoneiOSTests/SwiftDataTeamLibraryStoreTests`
5. Launch the app while signed in, record a match, and confirm Supabase receives the payload (check the `match_history` table for a new row with a non-null `owner_id`).

## Monitoring & Telemetry
- Logs
  - `AppLog.supabase.notice("Performing logout cleanup for local caches")` — emitted on sign out just before SwiftData wipes execute.
  - `AppLog.connectivity.notice("Queued completed match from watch while signed out")` — indicates watch payloads are being deferred until the phone signs in.
  - `Notification.Name.syncFallbackOccurred` contexts:
    - `ios.connectivity.queuedWhileSignedOut` when a payload is deferred.
    - `ios.connectivity.flushQueued` when deferred payloads flush after sign in.
- Dashboards
  - Track Supabase error rates for the `ingest_match_bundle` function. Spikes usually indicate phones attempting to sync without owning user rows.

## Recovery Plan if the Gate Must Be Relaxed
1. **Immediate Mitigation (hotfix build):**
   - Re-enable the onboarding skip by temporarily restoring `completeOnboardingWithoutAccount()` in `AuthenticationCoordinator` and gating UI entry points with build flags (`#if HOTFIX_ALLOW_SIGNED_OUT_USE`).
   - Ship to TestFlight with release notes explaining the regression and expected fix timeline.
2. **Server-Side Allow List:**
   - Add a Supabase RLS bypass role for trusted devices if a small cohort must sync urgently. Update the Supabase MCP connection string to include the temporary role.
3. **Disable Watch Connectivity Reception:**
   - If ownerless payloads begin to accumulate, comment out the `client.handleCompletedMatch` call in `IOSConnectivitySyncClient.activate()` and release a watch hotfix. This prevents unsigned phones from ingesting more local-only matches until the issue is resolved.
4. **Post-Mortem:**
   - Document the incident in the Supabase confluence/ADR, including the telemetry breadcrumbs and remediation timeline.

## Verification After Deploying a Fix
- Run the new auth gate tests:
  - `ConnectivityMergeTests.testHandleCompletedMatch_whenSignedOut_queuesUntilSignedIn`
  - `ConnectivityMergeTests.testHandleCompletedMatch_afterSignOut_requiresReauthentication`
  - `SupabaseMatchHistoryRepositoryTests.testHandleAuthState_whenSignedOut_wipesLocalCaches`
  - `SignedOutGateUITests.testGate_whenSignedOut_showsBlockingExperience`
- Manual checks on device:
  - Launch signed out → confirm the Signed Out gate appears and match tabs are inaccessible.
  - Sign in → ensure MainTabView loads, SwiftData entries persist, and the watch flushes pending snapshots.
  - Sign out again → confirm match history, schedule, journal, and team tabs are empty and `AppLog.supabase` records the cleanup message.
- Update release notes and customer docs with the Supabase requirement statement (see `docs/release-notes/2025-09-signed-in-requirement.md`).
