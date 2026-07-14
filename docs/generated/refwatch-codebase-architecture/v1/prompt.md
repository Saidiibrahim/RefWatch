# RefWatch Codebase Architecture — v1 Prompt Record

## Artifact

- Image: `refwatch-codebase-architecture.png`
- Generated: 2026-07-14
- Mode: built-in image generation, followed by targeted image edits
- Use case: `infographic-diagram`
- Intended surface: RefWatch engineering documentation and the Notion `Architecture Orientation` page

## Architecture facts locked into the prompt

- Apple Watch is the watchOS match-critical runtime and must remain usable offline.
- iPhone is the iOS companion.
- Both Apple targets use the shared Swift domain and services layer.
- SwiftData is an offline-first local store owned by the iPhone path, not the watch or shared layer.
- `BackendAPIClient` sends HTTPS requests with a Clerk session token.
- The target server path is Cloudflare Worker/Hono API → Drizzle ORM → node-postgres → Cloudflare Hyperdrive → PlanetScale Postgres.
- OpenAI is a server-side assistant branch from the Hono API.
- The target-backend migration is still in progress.

## Initial generation prompt

```text
Use case: infographic-diagram
Asset type: wide architecture infographic for the RefWatch Notion engineering documentation
Primary request: Create a polished, technically accurate landscape infographic titled exactly "RefWatch Codebase Architecture". It should explain the architecture to a software engineer at a glance.

Composition/framing: Use a clean left-to-right system map with two clearly separated zones: "LOCAL / OFFLINE (DEVICE)" on the left and "SERVER / CLOUD" on the right. Use generous spacing, crisp connectors, compact cards, and legible text at Notion page width.

Required structure:
1. Show Apple Watch / watchOS as the match-critical runtime and iPhone / iOS as its companion.
2. Show both Apple targets connected to "Shared Swift domain & services".
3. Show "SwiftData" as an "offline-first local store" under the iPhone path only. Do not connect Apple Watch or the shared Swift layer to SwiftData.
4. From iPhone, show "BackendAPIClient" crossing the device/cloud boundary over "HTTPS + Clerk session token".
5. Show this exact server sequence: "Cloudflare Worker + Hono API" → "Drizzle ORM" → "node-postgres" → "Cloudflare Hyperdrive" → "PlanetScale Postgres".
6. Add short subtitles: Hono handles routing, auth middleware, and HTTP; Drizzle provides typed schema, queries, and transactions; Hyperdrive is the deployed connection path; PlanetScale is the remote cloud database.
7. Show "OpenAI" as a server-side assistant branch from the Hono API.
8. Include a green device-side guardrail reading "Match runtime remains available offline".
9. Include an orange ribbon near the title reading "Target backend — migration in progress".

Style/medium: modern editorial software-architecture infographic; understated Apple-blue device zone, Cloudflare-orange API accents, teal data-path cards, and a restrained purple OpenAI card; white background; subtle grid; rounded cards; consistent technical line icons.

Text: Use only the labels specified above. Preserve capitalization and technology names exactly.

Constraints: Architecture accuracy is more important than decoration. Arrow direction must be unambiguous. Drizzle belongs to the Hono/TypeScript backend, not the Swift clients. Keep the offline watch guarantee visually prominent. No logos beyond simple technology-inspired line icons, no decorative characters, no watermark, no tiny illegible copy.
```

## Targeted correction passes

The initial render was visually reviewed and edited to correct connector topology. The final surgical edit used this prompt:

```text
Edit this existing architecture infographic with one exact topology correction only.

In the LOCAL / OFFLINE (DEVICE) section:
- DELETE the vertical blue arrow that starts at the bottom center of "Shared Swift domain & services" and points down into "SwiftData".
- ADD a separate blue arrow from the iPhone card directly to the SwiftData card. Route it around the RIGHT side of the Shared Swift box so it does not touch, originate from, or visually merge with the Shared Swift box.
- Preserve the existing Apple Watch -> Shared Swift arrow and iPhone -> Shared Swift arrow exactly.
- SwiftData must visually belong to iPhone only. There must be no line from Apple Watch or Shared Swift to SwiftData.
- Do not alter any words, labels, colors, icons, other arrows, layout, title, migration ribbon, backend sequence, or OpenAI branch.
- The final image must still read clearly at Notion page width.
```

Earlier correction passes established these invariants before the final edit:

- Apple Watch and iPhone each connect visibly to the shared Swift layer.
- The iPhone → `BackendAPIClient` → Hono request path is continuous.
- SwiftData sits below the iPhone and has no watch-owned path.
- All server labels, ordering, migration status, and the OpenAI branch remain unchanged.

## Versioning convention

Create future iterations as sibling directories (`v2`, `v3`, and so on). Each version should contain its selected image and its own `prompt.md`, including generation and correction prompts that materially affected the final artifact.
