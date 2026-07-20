# Installation & Tooling

## Prerequisites
- Xcode 16+ with watchOS 11 and iOS 18 SDKs. The README badge records the newer repository-validated toolchain; it is not the minimum requirement.
- Apple developer account for signing watchOS builds.
- Recommended: SwiftFormat (optional) and SwiftLint (optional) mirroring local setup.

## Clone & Bootstrap
```bash
git clone <repo-url>
cd RefWatch
open RefWatch.xcodeproj
```

## Dependency Notes
- All dependencies use Swift Package Manager; resolving happens automatically on first build.
- If package resolution fails, run `File > Packages > Reset Package Caches` in Xcode.

## Environment Configuration
- No secrets committed to the repo.
- Run `./scripts/setup.sh` to generate your local `Config.xcconfig`.
- (Recommended) Install git hooks to prevent committing secrets:
  - `./scripts/install-git-hooks.sh`
- Do not create or populate `RefWatchiOS/Config/Secrets.xcconfig` until the native/configuration lane is explicitly approved. When approved, copy the example and add only the public `BACKEND_API_BASE_URL`, `CLERK_PUBLISHABLE_KEY`, and `CLERK_FRONTEND_API_HOST` values for the selected environment.
- Do not add Clerk secret/JWT material, Clerk webhook secrets, PlanetScale/database credentials, OpenAI credentials, or Cloudflare administrative tokens to iOS xcconfig files.
- Set up the Worker locally from `api/` with `npm install`, `cp .dev.vars.example .dev.vars`, `npm run typecheck`, `npm test`, and `npm run dev`.
- The production foundation already has PlanetScale Postgres, cache-disabled Hyperdrive, the exact 5/54 seed, required production secret names, and an unrouted write-disabled Worker. Ledger-key recovery is blocked because the named Keychain record yields no recovered key bytes; do not retry an upload, create a placeholder escrow object, repair custody, bind, deploy, rotate, activate the ledger, or enable writes from this guide. Source remediation, Secrets Store escrow, functional recovery, production ledger activation/probe, remaining Clerk native/OAuth/webhook work, identity/data migration, traffic, and writes are separately gated. Follow `docs/references/backend-migration-cutover.md`; do not repeat foundation provisioning from this installation guide.
- The active iOS composition uses Clerk/backend adapters, including authenticated reference-catalog reads, and does not require Supabase configuration. The Supabase SDK/package dependency is removed. Provider-routed authenticated proof, final import/reconciliation, physical-device acceptance, and legacy Supabase-named repository/type/source-path cleanup remain incomplete.
- Ensure custom schemes are marked as *Shared* before running CI commands.
