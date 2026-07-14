# Cutover Bundle Validator — 2026-07-14

The final source export and identity map must be stored only under ignored,
access-controlled `.cutover/` or `api/.cutover/` paths. Validate from `api/`:

```sh
npm run cutover:validate -- .cutover/final-bundle.json
npm test -- --run test/cutoverBundle.test.ts
npm run typecheck
```

The validator requires and cross-checks:

- a Supabase MCP source marker, UTC capture time, and `REPEATABLE READ, READ ONLY`
  boundary;
- an explicitly present exported row array, count, and table-specific
  import/seed/blocked/zero-row disposition for every one of the 39 live public
  tables; a non-empty table without a verified import contract hard-blocks
  cutover and cannot be accepted for archival;
- exact count parity between snapshot metadata and export arrays;
- exactly one non-empty opaque Clerk subject for every existing
  `public.users.id`, with no invented/unknown app-user UUID;
- the exact exported source Auth UUID set, its set difference from public users,
  and a reasoned disposition for every actual auth-only identity;
- collision-safe auth-only migration contracts: either a distinct new empty app
  user payload or a reviewed merge using the existing app user's Clerk subject;
- owner and foreign-key checks over exported rows, including currently verified
  imports plus blocked team children, devices, and AI rows; event team/member
  consistency; the reference catalog's composite competition/season key;
  schedules, matches, page-to-match owner consistency, workouts, and child rows;
- global-seed treatment for workout presets only when every row has
  `created_by = null`; user-owned rows require the import contract, and a mixed
  table requires exact, non-overlapping seed/import ID partitions;
- a deterministic dependency order covering every currently verified import
  table. Previously empty tables whose source/target shapes drift must remain
  zero or the cutover remains blocked until their import contract is added.

Vitest covers a valid complete bundle, missing/invented mappings, missing
zero-row arrays, an invented auth-only identity with a colliding migration,
unsupported import dispositions, a non-repeatable snapshot, count drift, and
relation/owner orphans, composite reference-season drift, cross-owner pages,
and user-owned presets mislabeled as global seeds. The complete API suite
passes 37/37 across seven files.

This tool is validation-only. No final bundle exists yet, it does not contact
PlanetScale, and it cannot replace the reviewed Clerk mapping, final MCP
snapshot, production import, or source/target reconciliation evidence.
