# Installation & Tooling

## Prerequisites
- Xcode 16 (latest GM) with watchOS 11 and iOS 18 SDKs.
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
- Copy `Secrets.example.xcconfig` to `Secrets.xcconfig` and add your local non-OpenAI values for cloud features (for example Supabase and Google Sign-In).
- OpenAI credentials are server-side only for the assistant proxy and should not be added to the iOS app xcconfig files.
- Deploy the assistant proxy after linking the Supabase CLI to your project:
  - `supabase functions deploy assistant-responses --project-ref <project-ref>`
  - `supabase secrets set OPENAI_API_KEY=<server-side-openai-key> --project-ref <project-ref>`
- The `assistant-responses` function requires the Supabase JWT from the signed-in app user and will fail if the server-side `OPENAI_API_KEY` secret is missing.
- Ensure custom schemes are marked as *Shared* before running CI commands.
