# Installation & Tooling

## Prerequisites
- Xcode 16 (latest GM) with watchOS 11 and iOS 18 SDKs.
- Apple developer account for signing watchOS builds.
- Recommended: SwiftFormat (optional) and SwiftLint (optional) mirroring local setup.

## Clone & Bootstrap
```bash
git clone <repo-url>
cd RefWatch
open RefZone.xcodeproj
```

## Dependency Notes
- All dependencies use Swift Package Manager; resolving happens automatically on first build.
- If package resolution fails, run `File > Packages > Reset Package Caches` in Xcode.

## Environment Configuration
- No secrets committed to the repo. Request Supabase keys and any feature flags from the maintainers.
- Ensure custom schemes are marked as *Shared* before running CI commands.
