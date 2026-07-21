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
- [x] Apply/read back the bundled reference-catalog seed in production
  PlanetScale. The historical foundation installed migration `0002`'s five
  competitions and 54 teams with zero application users. The greenfield
  baseline must inventory the complete deterministic seed from reviewed
  repository sources separately from zero `app_users` and user-owned rows.
- [ ] Retire legacy Supabase-named repository/type/source-path compatibility
  debt after accepted traffic, without breaking the persisted SwiftData schema.
- [x] Preserve SwiftData/offline identity behavior and user-switch/logout cleanup
  in implementation and automated regression coverage. Unresolved Clerk startup
  no longer emits a false logout; the backend identity mapping persists for
  offline launches, revalidates online, and clears on invalidation. The async
  invalidation regression is covered and the fresh full iOS target passes
  94/94 on iPhone 15 Pro Max/iOS 17.0.1.
- [x] Make collection synchronization tombstone- and late-commit-safe for teams,
  competitions, venues, schedules, and matches. Only completed pulls advance
  cursors; first/relaunch pulls start at the epoch; later pulls overlap by 15
  minutes; inclusive server replay applies only strictly newer rows and never
  overwrites dirty local state. Five focused cursor/replay tests pass on the
  iPhone 15 Pro Max/iOS 18.5 simulator.
- [ ] Prove production sign-in, clean-account creation, offline backlog, logout,
  user switching, and match lifecycle on the physical iPhone target during the
  writable production-acceptance phase.
- [x] Add targeted auth/client/repository tests and run the available simulator
  Apple verification. The current full `RefWatchiOSTests` run passes 76 XCTest
  plus 18 Swift Testing cases (94/94) on iPhone 15 Pro Max/iOS 17.0.1; the
  affected cursor suite passes 5/5 on iOS 18.5. A broad Xcode 27 beta/iOS 18.5
  run repeatably aborts with an allocator double-free in 15 unrelated legacy
  cases, classified as a bounded tool/runtime incompatibility rather than a
  product pass or failure. The current generic Release simulator build
  succeeds, but reads back `CFBundleIdentifier=.RefWatch`, no team, localhost,
  a test Clerk key, `clerk.localhost`, and no callback URL scheme; it is not
  production configuration acceptance. Historical receipts remain available
  for the prior 89/89 iOS target, 19-pass/2-skip iOS UI target, 11/11 watch UI
  target, 107 pass/4 simulator-host-skip watch unit target, and `0.9.0 (2)`
  embedded watch/widget plists.
- [x] Resolve the production native identity from installed Apple signing
  metadata: Team/App ID Prefix `6NV7X5BLU7`, Bundle ID
  `com.IbrahimSaidi.RefWatch`, application identifier
  `6NV7X5BLU7.com.IbrahimSaidi.RefWatch`, and Clerk callback
  `com.IbrahimSaidi.RefWatch://callback`.
- [ ] Align the non-secret Release/ClerkKit configuration with that production
  identity, register/verify the native callback, and verify the embedded
  Release plist plus actual Apple/Google callbacks. The current Release
  readback remains `.RefWatch`, no team, localhost, a test Clerk placeholder,
  `clerk.localhost`, and no callback URL scheme.
- [ ] Complete physical iPhone 15 Pro Max and Apple Watch Series 9 acceptance
  after the clean Clerk/Worker/PlanetScale path is writable and accepted by the
  automated matrix. No migrated legacy identities/data are required. No
  physical iPhone or Apple Watch was connected during the fresh baseline.
