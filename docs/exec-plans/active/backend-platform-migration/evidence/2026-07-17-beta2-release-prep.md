# Beta 2 Release Preparation — 2026-07-17

## Scope

Prepare the migration branch for engineering checkpoint prerelease
`v0.9.0-beta.2`. This is build and repository evidence only; it does not satisfy
physical-device, authenticated production-route, data-import, rollback, traffic,
or production-write acceptance.

## Version and build proof

- Shipping iOS, watchOS, and widget configurations are aligned at marketing
  version `0.9.0`, build `2`.
- A generic iOS Release build with the embedded watch app and widget passed with
  Xcode 27.0 beta build `27A5209h` and code signing disabled.
- The first Release attempt exposed a real compile error: a debug-only UI-test
  catalog fixture was referenced from an unconditional call site. The seeding
  block is now compiled only under `#if DEBUG`, preserving Debug UI-test behavior
  and keeping the fixture out of the Release build.
- Built plist readback reports `0.9.0 (2)` for the iOS app, embedded watch app,
  and embedded widget extension.
- The built watch plist contains only `workout-processing` in
  `WKBackgroundModes`.
- The built iOS plist has no `OPENAI_API_KEY` entry.

Sanitized build command:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project RefWatch.xcodeproj \
  -scheme RefWatchiOS -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/RefWatch-beta2-ios \
  CODE_SIGNING_ALLOWED=NO -quiet build
```

## API and repository proof

- API TypeScript typecheck: passed.
- API Vitest: 78/78 across 14 files.
- Mutation coverage: 35 schema tables, 22 trigger-captured tables, 13 explicit
  exclusions, six included writers, and two control-plane writers.
- Production Wrangler dry-run: passed at 1,508.06 KiB total / 271.48 KiB gzip.
- Ledger-rehearsal manifest and all JSON receipts: passed.
- Gitleaks 8.24.3: the full branch commit range from `main` through the beta 2
  prep head was scanned; no leaks found after six exact fingerprint-only false-positive
  dispositions. No path, rule, or regex was broadly allowlisted.

The real-Postgres integration suite was not rerun during release preparation
because its runner creates a privileged temporary role and mutates the isolated
rehearsal branch. Its existing 19/19 provider-backed evidence remains recorded,
but is not claimed as fresh beta 2 execution.
