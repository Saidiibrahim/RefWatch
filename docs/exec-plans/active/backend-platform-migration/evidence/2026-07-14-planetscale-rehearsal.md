# PlanetScale Rehearsal — 2026-07-14

## Scope

- Organization: `ibrahim-aka-ajax`
- PlanetScale Postgres database: `refwatch`
- Disposable branch: `cutover-rehearsal-20260714`
- Region: Sydney
- Cluster: `PS_DEV`
- Parent: production `main`
- Production `main` was not modified.

## Procedure

The branch was created from `main` with the following sanitized command:

```sh
pscale branch create refwatch cutover-rehearsal-20260714 \
  --from main --cluster-size PS_DEV --wait \
  --org ibrahim-aka-ajax --format json
```

An ephemeral 30-minute admin role was
created, supplied to `npm run db:migrate` only through the process environment,
and deleted on exit. No connection string or password was printed or persisted
in this artifact.

```sh
cd api
DATABASE_URL='<ephemeral redacted URL>' npm run db:migrate
```

The first apply exposed an ordering defect in migration `0003`: the composite
unique index was created after its dependent foreign key. The migration was
corrected to create the index first. The complete six-migration set then
applied successfully to the disposable branch.

## Provider Readback

- Drizzle migrations recorded: 6
- Public tables: 26
- Required legacy/reference tables present: 5 of 5
  (`pages`, `workout_sessions`, `workout_presets`,
  `reference_disciplinary_codes`, `reference_disciplinary_rules`)
- `reference_competitions`: 5 rows
- `reference_teams`: 54 rows
- Venue latitude/longitude type: `double precision`
- Match assessment mood enum present

This proves schema portability on a non-production branch. It does not prove
source data import, identity mapping, Hyperdrive runtime access, Worker
deployment, or production readiness.

This artifact is a recorded operator result. The exact start/end timestamps,
CLI version, branch ID, migration hashes, and sanitized raw query output were
not retained in the first rehearsal and must be included in the production
apply artifact. Claims here are limited to the recorded cardinalities and type
checks; a full column/constraint/index inventory remains a production gate.

## Provider Recheck

At `2026-07-14T07:19:53Z`, a fresh read-only PlanetScale provider query against
the primary confirmed:

- production `main`: 0 public base tables;
- rehearsal: 26 public base tables;
- Drizzle migration ledger: 6 rows in `drizzle.__drizzle_migrations`;
- rehearsal rows: 5 reference competitions, 54 reference teams, 30
  disciplinary codes, 3 disciplinary rules, and 20 workout presets.

The provider schema readback also returned the same 26 named public tables as
the earlier rehearsal. This confirms that production remains untouched and the
rehearsal schema/data has not drifted; it does not promote the rehearsal into
production evidence.
