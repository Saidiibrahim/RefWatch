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
- Copy `RefWatchiOS/Config/Secrets.example.xcconfig` to `RefWatchiOS/Config/Secrets.xcconfig` and add `BACKEND_API_BASE_URL`, `CLERK_PUBLISHABLE_KEY`, and `CLERK_FRONTEND_API_HOST` for the migrating cloud path.
- Do not add Clerk secret/JWT material, Clerk webhook secrets, PlanetScale/database credentials, OpenAI credentials, or Cloudflare administrative tokens to iOS xcconfig files.
- Set up the Worker locally from `api/` with `npm install`, `cp .dev.vars.example .dev.vars`, `npm run typecheck`, `npm test`, and `npm run dev`.
- Production setup requires Clerk native-app/webhook configuration, PlanetScale Postgres, a Cloudflare Hyperdrive binding, and Wrangler secrets. Follow `docs/references/backend-migration-cutover.md`.
- The active iOS composition uses Clerk/backend adapters, including authenticated reference-catalog reads, and does not require Supabase configuration. The Supabase SDK/package dependency is removed. Staging Worker/Hyperdrive readiness and disposable 5/54 catalog readback passed; production deployment/data import/catalog apply-readback, iOS test acceptance, and legacy Supabase-named repository/type/source-path cleanup remain incomplete.
- Ensure custom schemes are marked as *Shared* before running CI commands.
