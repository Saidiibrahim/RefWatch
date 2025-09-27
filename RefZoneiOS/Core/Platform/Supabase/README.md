# Supabase Platform Integration (iOS)

This folder isolates the iOS-specific adapters that talk to Supabase so the rest of the app can stay platform-agnostic.

## Contents
- `SupabaseEnvironment.swift`: resolves the Supabase URL and anon key from `Info.plist` placeholders or environment variables. Throws descriptive errors when configuration is missing or unresolved.
- `SupabaseClientProvider.swift`: lazily constructs and caches the shared `SupabaseClient`, keeps configuration lookup in one place, and aligns the Functions client with the active Supabase GoTrue session.
- `SupabaseHelloWorldService.swift`: lightweight smoke-test service that invokes the `hello-world` Edge Function and decodes the response message.

## Testing
- `RefZoneiOSTests/SupabaseHelloWorldServiceTests.swift` exercises the service with protocol-based mocks, covering the happy path and error propagation.

## Next Steps
1. Decide where the app stores `SUPABASE_URL` and `SUPABASE_ANON_KEY` (e.g. xcconfig → Info.plist placeholders) and document the workflow in the contributor guide. **(done)**
2. Replace the hello world service with the real entitlements/ingest calls while keeping the smoke test (or similar) around for diagnostics.
3. Consider wiring a debug screen or Diagnostics command that surfaces the hello-world round-trip for quick connectivity checks. **(Settings → Supabase Connectivity)**
