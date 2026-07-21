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
- Production provider work is authorized, but this installation guide is not
  the operator procedure. The authoritative Apple App ID Prefix is
  `6NV7X5BLU7`, the signed production Bundle ID is
  `com.IbrahimSaidi.RefWatch`, and the native redirect is
  `com.IbrahimSaidi.RefWatch://callback`. The release
  `RefWatchiOS/Config/Secrets.xcconfig` is still absent; create/populate it only
  at the reviewed release destination. Add only the public `BACKEND_API_BASE_URL`,
  `CLERK_PUBLISHABLE_KEY`, and `CLERK_FRONTEND_API_HOST` values for the selected
  environment.
- Do not add Clerk secret/JWT material, Clerk webhook secrets, PlanetScale/database credentials, OpenAI credentials, or Cloudflare administrative tokens to iOS xcconfig files.
- Set up the Worker locally from `api/` with `npm install`, `cp .dev.vars.example .dev.vars`, `npm run typecheck`, `npm test`, and `npm run dev`.
- The 2026-07-20 production preparation provisioned least-privilege
  write-capable PlanetScale role `hvk7iheytj62` and cache-disabled Hyperdrive
  `920ca5b108034b2bb8700cf0201ac55f`, verified the exact 5/54 repository seed,
  and left the deployed Worker path unchanged. Reverify and use that prepared
  pair; do not repeat working role/Hyperdrive/domain/DNS/key setup or perform a
  production mutation from this guide.
- The 2026-07-20 launch is greenfield. The historical 43 Supabase Auth
  identities, 42 profiles, 1,106 application rows, and
  `testing@refwatch.com` are disposable; no legacy identity mapping or data
  import is required. Clean-target checks distinguish zero app users/user-owned
  rows from the deterministic global reference seed reviewed from repository
  sources.
- Ledger escrow/recovery/activation is deferred and non-blocking. The launch
  requires zero preparing, open, or capture-enforced epochs and zero Queue,
  cron, or D1 consumers; provisioned inactive resources may remain. Initial
  recovery may stop traffic/writes, route to the write-disabled Worker, roll
  back Worker/client versions, reset/reseed PlanetScale, recreate test
  identities, and rerun the launch.
- The exact production Clerk instance is
  `ins_3GWFGUd1rI6hx5lWlUxMYAkxdac`, domain `refwatch.ibby.ai`, and
  issuer/Frontend API `https://clerk.refwatch.ibby.ai`. Full provider cutover is
  authorized but not completed merely by this documentation update. Follow
  `docs/references/backend-migration-cutover.md`; keep secrets non-disclosing,
  and do not commit or publish without a separate request.
- The active iOS composition uses Clerk/backend adapters, including
  authenticated reference-catalog reads, and does not require Supabase
  configuration. The Supabase SDK/package dependency is removed. Provider-routed
  authenticated proof, physical-device acceptance, traffic/write promotion, and
  reviewed compatibility cleanup remain incomplete until evidence records them.
- Ensure custom schemes are marked as *Shared* before running CI commands.
