# PLAN — Supabase Signed-In Requirement (iOS)

## Summary
RefZone iOS was intentionally built to let referees run the full experience while signed out, queuing work locally and syncing only when Supabase credentials became available. Pivoting to a "signed-in required" stance eliminates the ownerless data paths that complicate our RLS policies, profile synchronization, and backlog processing while bringing iOS behaviour in line with how we already treat the watchOS-first workflow.

Gating the iPhone app behind Supabase auth lets us guarantee every match, schedule, journal, and team edit carries an `ownerId`, simplifies error handling (no more retrying pushes with missing identity), and reduces surface area for data leakage when a device is lost. The watch can remain local-first; the phone becomes the authenticated hub that unlocks sync, trends, and management tools.

This plan scopes the UX, storage, and sync updates needed to hard-stop signed-out usage on iOS, migrate any legacy offline data safely, and keep the watch pairing experience intact.

## Current Findings
- `RefZoneiOS/Features/Authentication/Coordinators/AuthenticationCoordinator.swift:93` still exposes `completeOnboardingWithoutAccount()`, so a signed-out user can dismiss onboarding and proceed into the tabs.
- `RefZoneiOS/Features/Authentication/Views/WelcomeView.swift:90` and `RefZoneiOS/Features/Authentication/Views/SignInView.swift:139` both surface "Continue without account" actions, reinforcing the legacy offline-first contract.
- `RefZoneiOS/App/RefZoneiOSApp.swift:148` always instantiates `MainTabView` and all stores before auth is resolved, only layering the welcome/sign-in flow as a full-screen cover; core features remain available underneath when `state == .signedOut`.
- `RefZoneiOS/Features/Matches/Views/MatchesTabView.swift:27` and `RefZoneiOS/Features/Matches/Views/UpcomingMatchEditorView.swift:24` enable match creation, scheduling, and journal flows without checking authentication state.
- `RefZoneiOS/Core/Platform/Supabase/SupabaseMatchHistoryRepository.swift:93` and peers (`SupabaseScheduleRepository`, `SupabaseTeamLibraryRepository`) gracefully degrade to local-only behaviour when `ownerUUID` is nil, continuing to accept writes that persist without an owner.
- `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataMatchHistoryStore.swift:83`, `SwiftDataJournalStore.swift:46`, and the other SwiftData stores merely attach `ownerId` if one exists; records saved while signed out retain `nil` ownership indefinitely.
- `RefZoneiOS/Core/Platform/Connectivity/IOSConnectivitySyncClient.swift:67` saves watch-sent snapshots immediately, only attaching ownership if the phone happens to be signed in; otherwise the match lands locally with no `ownerId`.
- `RefZoneiOS/Features/Settings/Views/SettingsTabView.swift:96` reassures users they can "continue using the app offline", so copy and UX contradict the new requirement.

## Constraints & Open Questions (Resolved)
- Existing local records: assume none; no backfill required.
- Multi-user support: out of scope; the phone is single-account and must stay signed in. iOS should stop persisting new data locally once the gate ships.
- Watch uploads: Apple Watch remains local-first, but pairing/sync requires the iPhone to be signed in; enforce authentication before accepting watch connectivity payloads.
- SwiftData JSON fallback: retire `MatchHistoryService` and similar fallbacks so Supabase becomes the only storage path.
- Staged rollout: not needed; release directly once implementation is complete.

## Phase 1 — Align Onboarding & Messaging With the New Contract
- Remove skip affordances (`completeOnboardingWithoutAccount`, "Continue without account") and update welcome/sign-in copy to state that an account is required on iOS.
- Update `SettingsTabView` messaging to reflect mandatory sign-in and direct signed-out users to authenticate before performing any action.
- Audit marketing copy, release notes, and internal docs so the new requirement is explicit before the build ships.

### Phase 1 Status — 2025-09-29
- [x] Welcome and sign-in flows now communicate that RefZone on iPhone requires a Supabase account; skip affordances removed.
- [x] Settings messaging points signed-out users to authenticate before accessing match, schedule, or team features.
- [x] Release note snippet prepared: "RefZone on iPhone now requires a signed-in Supabase account. Continue logging matches on Apple Watch offline and they'll sync once you sign in on your phone."

## Phase 2 — Gate the App Shell and Feature Entry Points Behind Auth
- Introduce a root-level guard that renders a dedicated signed-out experience (e.g., blocking screen or auth flow) instead of instantiating `MainTabView` while unauthenticated.
- Ensure `AppRouter`, `AuthenticationCoordinator`, and any deep links always resolve back to the sign-in flow when `auth.state == .signedOut`.
- Harden feature views (`MatchesTabView`, `MatchSetupView`, `UpcomingMatchEditorView`, library editors, trends) to respect the gate even if the user bypasses navigation, ideally by guarding actions at the view-model layer.
- Audit app-wide toolbar buttons, context menus, and shortcuts to guarantee they either hide or redirect to sign-in when no session exists.

### Phase 2 Status — 2025-09-29
- [x] Root scene now swaps `MainTabView` for a signed-out gate and only boots sync services when a Supabase session exists.
- [x] `AuthenticationCoordinator` automatically routes signed-out users into the sign-in flow; `AppRouter.presentAuthentication` continues to surface the coordinator cover.
- [x] Matches, match setup, schedule editor, trends, and assistant surfaces render a signed-out placeholder that links back to authentication if somehow accessed without a session.
- [x] Signed-out sheets/toolbars/buttons now suppress match creation and scheduling actions until the user signs in.

## Phase 3 — Harden Data Ownership & Migration Paths
- Require a live `currentUserId` before mutating SwiftData stores; surface actionable errors when writes are attempted while signed out.
- When the gate is active, eliminate the SwiftData JSON fallbacks so all persistence flows through Supabase-backed repositories.
- Update repository retry logic to assume identity is always present; simplify or remove branches that handled missing `ownerUUID`.

### Phase 3 Status — 2025-09-29
- [x] All SwiftData-backed stores now enforce a signed-in Supabase user before mutating, surfacing `PersistenceAuthError.signedOut` for blocked operations.
- [x] Legacy JSON fallbacks have been removed; iOS now builds exclusively on the SwiftData + Supabase persistence stack.
- [x] Supabase repositories assume owner identity is present, streamlining retry logic and owner attachment.

## Phase 4 — Logout, Watch Connectivity, and Legacy Data Hygiene
- Define logout semantics: wipe or invalidate local SwiftData caches so no data survives for the next user on the shared device.
- Update `ConnectivitySyncController`/`IOSConnectivitySyncClient` so incoming watch payloads are queued or rejected until the phone signs in; pairing should require an authenticated session up front.
- Ensure the watch continues to operate offline but clearly communicates that syncing requires an authenticated phone.
- Add telemetry/OSLog breadcrumbs for signed-out access attempts to help QA verify the gate and monitor production once released.

### Phase 4 Status — 2025-09-29
- [x] iOS logout now clears SwiftData-backed history, schedule, journal, and team caches plus pending sync metadata so the next user starts fresh.
- [x] Connectivity controller listens to auth state; watch payloads queue while signed out and flush with breadcrumbs once a Supabase session returns.
- [x] Telemetry via `AppLog.connectivity` and `.syncFallbackOccurred` tracks rejected/queued payloads and sign-out wipes for QA visibility.

## Phase 5 — Verification, Tooling, and Release
- Expand unit/UI tests to cover the signed-out gate, the watch-to-phone sync flow with enforced auth, and logout wipes.
- Provide a runbook outlining how to remove legacy fallback stores during the update and recover if the auth gate fails in production.
- Release directly (no staged rollout), accompanied by updated release notes and customer docs that call out the Supabase requirement on iPhone while reiterating the watch’s local-first behaviour.

### Phase 5 Status — 2025-09-30
- [x] Added unit and UI coverage for the signed-out gate, watch connectivity queueing, and logout cache wipes.
- [x] Documented the Supabase auth gate runbook covering fallback removal and recovery steps.
- [x] Published updated release notes and customer messaging that highlight the iPhone sign-in requirement and watch offline behaviour.
