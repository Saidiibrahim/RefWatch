---
task_id: 02
plan_id: PLAN_backend-platform-migration
plan_file: ./PLAN_backend-platform-migration.md
title: Replace active iOS Supabase adapters with Clerk and backend API adapters
phase: Phase 2 - iOS
---

- [x] Add vendor-neutral auth-state, token, and backend-identity seams.
- [x] Add ClerkKit/ClerkKitUI and a Clerk auth controller without UUID-parsing Clerk subjects.
- [x] Add the typed backend API client, error mapping, and streaming foundation.
- [x] Move active match, schedule, journal/assessment, team, competition, venue, assistant, and parser adapters to Worker routes.
- [x] Move active reference-team and competition catalog reads behind an authenticated backend service; feature views no longer query Supabase directly.
- [x] Remove the Supabase SDK/package dependency from the compiled app targets and package lock.
- [ ] Apply/read back the bundled reference-catalog seed in production PlanetScale and retire legacy Supabase-named repository/type/source-path compatibility debt. Disposable provider readback now proves the 5/54 catalog; production remains untouched.
- [ ] Preserve SwiftData/offline backlog behavior and user-switch/logout cleanup. Unresolved Clerk startup no longer emits a false logout, and the backend identity mapping now persists for offline launches, revalidates online, and clears on invalidation. The async invalidation regression is covered and the iOS unit target passes 89/89; physical-device backlog evidence remains.
- [ ] Add targeted auth/client/repository tests and run mandated Apple verification. Targeted tests cover startup auth resolution, transport/token-unavailable offline identity fallback, server auth rejection, and persisted-cache invalidation. Generic build/build-for-testing pass, the iOS unit target passes 89/89 on iPhone 15 Pro Max/iOS 17.0.1, and the full UI target passes with 19 passed, 0 failed, and 2 bounded skips on iPhone 15 Pro Max/iOS 18.5. On a Series 9 (45mm)/watchOS 11.5 simulator, all 11 watch UI cases pass and the unit target executes 111 cases with 107 passed, 0 failed, and 4 explicit simulator-host skips. Watch/widget versions are aligned and built-plist verified at `0.8.2 (1)`. Physical iPhone/watch acceptance remains; both devices were offline during the final audit.
