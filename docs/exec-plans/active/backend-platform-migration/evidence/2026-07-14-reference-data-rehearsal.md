# Reference Data Rehearsal — 2026-07-14

The live non-user reference catalog and global workout presets were rehearsed
against the isolated PlanetScale branch `cutover-rehearsal-20260714`.
Production `main` was not changed.

The insert preserved every source column, UUID, array, nullable value, and
timestamp. Post-import source and target readback matched exactly when hashing
ordered `jsonb` rows:

| Table | Source | Target | Source/target MD5 |
| --- | ---: | ---: | --- |
| `reference_disciplinary_codes` | 30 | 30 | `caecd3a320f20f6e878cc4a6b92df8a9` |
| `reference_disciplinary_rules` | 3 | 3 | `ee76762104f701c0d8a3697142f2bebd` |
| `workout_presets` | 20 | 20 | `8b9e346b9ea92e8bc34cc4c09ab56b7e` |

The already-seeded 5 reference competitions and 54 reference teams also match
the source exactly across all business columns. Their audit timestamps differ
because the rehearsal migration created them separately. Excluding only
`created_at`/`updated_at`, source and target hashes are
`d56166798ab11268a1758c5cc8162c01` (competitions) and
`a562b3b7e9fb153e6e1c614a8df3d6cf` (teams).

## Reproduction record

Execution window: `2026-07-14T02:21Z`. Supabase and PlanetScale MCP operations
both returned success; production was not selected. Source export used:

```sql
select
  (select jsonb_agg(to_jsonb(c) order by c.sort_order, c.code)
   from public.reference_disciplinary_codes c) as codes,
  (select jsonb_agg(to_jsonb(r) order by r.rule_type, r.recipient_type)
   from public.reference_disciplinary_rules r) as rules;

select jsonb_agg(to_jsonb(p) order by p.id) as presets
from public.workout_presets p
where created_by is null;
```

An in-memory operator transformed only the named schema columns into escaped
Postgres literals, including `ARRAY[...]::text[]`, and executed one `INSERT`
statement per target table through PlanetScale's write-query operation. The 20
workout presets all had `created_by is null`, so their import did not depend on
an identity mapping. Each
statement was its own implicit transaction; there was no cross-table explicit
transaction. No export file or credential was written. The insert template was:

```sql
insert into <target_table> (<explicit ordered column list>)
values (<escaped source row values>), ...;
```

Source and primary-target readback then used the same deterministic query:

```sql
select
 (select count(*) from reference_disciplinary_codes) as code_count,
 (select md5(string_agg(to_jsonb(c)::text, '' order by c.id))
  from reference_disciplinary_codes c) as code_hash,
 (select count(*) from reference_disciplinary_rules) as rule_count,
 (select md5(string_agg(to_jsonb(r)::text, '' order by r.id))
 from reference_disciplinary_rules r) as rule_hash;

select count(*) as preset_count,
       md5(string_agg(to_jsonb(p)::text, '' order by p.id)) as preset_hash
from workout_presets p;
```

For the already-seeded catalog, the same source/target query hashed explicit
business-column `jsonb_build_object(...)` values ordered by UUID, excluding
only `created_at` and `updated_at`; this is why those hashes are labeled
business-row rather than complete-row hashes.

Sanitized source readback was `30 / caecd3a320f20f6e878cc4a6b92df8a9`
and `3 / ee76762104f701c0d8a3697142f2bebd`; PlanetScale returned the same
counts/hashes. This records an operator rehearsal, not a reusable final import
artifact; the production importer still needs a reviewed, repeatable script.

The first workout-preset insert attempt was rejected atomically because the
JSONB `exercises` array was emitted as `text[]`; target count remained zero.
The corrected statement emitted `exercises` as JSONB, succeeded, and produced
the matching 20-row hash above. This failed rehearsal attempt caused no partial
write.

This is a rehearsal result, not a final export. The final repeatable-read source
snapshot must be compared again immediately before production import. The
remaining user-owned/global source data and all identity mappings are pending.
