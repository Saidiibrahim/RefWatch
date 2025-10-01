# Supabase User Metadata Normalization Plan *(Completed 2025-09-29)*

> **Why a separate normalization trigger?**  `public.sync_user_from_auth()` continues to mirror Supabase auth rows into `public.users`, but multiple paths (migrations, admin tools, future services) can mutate `public.users` directly. The new `public.normalize_user_provider_metadata()` trigger keeps provider arrays/primary provider normalized for every insert/update of `raw_app_metadata`, regardless of origin. Keeping the responsibilities split lets us roll out schema changes incrementally, backfill safely (`UPDATE public.users SET raw_app_metadata = raw_app_metadata`), and test each piece in isolation.

## Goals
- Keep `public.users` tightly aligned with Supabase auth data while staying query-friendly.
- Ensure frequently accessed properties (name, provider info, verification flags) live in proper typed columns.
- Normalize JSON blobs so downstream features can rely on JSON operators without custom parsing.

## Current Findings
- `raw_app_metadata.providers` and `raw_user_metadata.custom_claims` are stored as JSON strings instead of structured JSON, breaking `@>` queries and forcing manual parsing.
- Boolean flags inside `raw_user_metadata` (e.g. `email_verified`, `phone_verified`) arrive as string literals, preventing direct casting or indexing.
- `display_name` defaults to the email address even when `full_name` is present, producing poor UX and duplication in UI copy.
- Auth-centric flags (`is_sso_user`, `is_anonymous`, primary provider) are only available inside the raw blobs; several feature tables reference provider context for ownership/permissions, so indexing on raw JSON will be brittle.

## Proposed Improvements
1. **Typed Columns**
   - Add/confirm nullable columns: `is_sso_user boolean default false`, `is_anonymous boolean default false`, `primary_provider text`, `provider_list text[]`.
   - Normalize `provider_list`/`primary_provider` with a `BEFORE INSERT OR UPDATE OF raw_app_metadata` trigger that coerces the metadata array, dedupes and lowercases providers, and assigns `primary_provider` to the first valid entry. Document trigger behavior with the migration so downstream teams understand the write-path contract.
   - Consider optional `given_name` / `family_name` columns if product wants more granular personalization.
2. **JSON Hygiene**
   - Store `raw_app_metadata.providers` as a JSON array, `raw_user_metadata.custom_claims` as a JSON object, and booleans as true JSON booleans.
   - Add database constraints or generated columns to keep types honest (e.g. `check (raw_app_metadata ? 'providers' and jsonb_typeof(raw_app_metadata -> 'providers') = 'array')`).
3. **Display Name Logic**
   - When upserting, prefer `full_name` > `name` > `email` for `display_name`.
   - Optionally derive `avatar_url` from metadata when absent.
4. **Backfill & Testing**
   - Write a SQL backfill migration that coerces existing rows to the new types.
   - Extend the upsert helper tests to cover multiple providers and missing metadata scenarios.

## Implementation Steps
1. **Database Migration**
   - Alter `users` table to add the proposed columns (with sensible defaults) and enforce JSON type checks.
   - Create a `normalize_user_provider_metadata()` function plus a `BEFORE INSERT OR UPDATE OF raw_app_metadata` trigger that: coerces `raw_app_metadata->'providers'` into a `jsonb` array (fallback `[]`), strips blanks, lowercases and dedupes values while preserving stable order, assigns the first provider to `primary_provider`, and writes the array to `provider_list`. Ensure the trigger no-ops when metadata is unchanged to avoid churn.
     ```sql
     create or replace function public.normalize_user_provider_metadata()
     returns trigger
     language plpgsql
     as $$
     declare
       providers_json jsonb := coalesce(NEW.raw_app_metadata -> 'providers', '[]'::jsonb);
       cleaned text[] := array[]::text[];
       provider text;
     begin
       if TG_OP = 'UPDATE' and NEW.raw_app_metadata is not distinct from OLD.raw_app_metadata then
         return NEW;
       end if;

       if jsonb_typeof(providers_json) <> 'array' then
         providers_json := '[]'::jsonb;
       end if;

       for provider in
         select lower(trim(both '"' from value::text))
         from jsonb_array_elements(providers_json) as e(value)
       loop
         if provider <> '' and provider <> 'null' and not provider = any(cleaned) then
           cleaned := array_append(cleaned, provider);
         end if;
       end loop;

       NEW.provider_list := cleaned;
       NEW.primary_provider := case when array_length(cleaned, 1) >= 1 then cleaned[1] else null end;
       NEW.raw_app_metadata := jsonb_set(
         NEW.raw_app_metadata,
         '{providers}',
         coalesce(to_jsonb(cleaned), '[]'::jsonb),
         true
       );

       return NEW;
     end;
     $$;

     drop trigger if exists trg_normalize_user_provider_metadata on public.users;
     create trigger trg_normalize_user_provider_metadata
       before insert or update of raw_app_metadata on public.users
       for each row execute function public.normalize_user_provider_metadata();
     ```
   - Backfill existing row(s) with a staged update to rebuild JSON structures and booleans. Guard any casts so malformed legacy strings (e.g. `"[\"auth_time\": 1758859612]"`) fall back to sane defaults instead of aborting the transaction:
     ```sql
     with normalized as (
       select id,
              case
                when (raw_app_metadata->>'providers') ~ '^\\s*\['
                  then (raw_app_metadata->>'providers')::jsonb
                else '[]'::jsonb
              end as providers_json,
              case
                when (raw_user_metadata->>'custom_claims') ~ '^\\s*\{'
                  then (raw_user_metadata->>'custom_claims')::jsonb
                else '{}'::jsonb
              end as custom_claims_json,
              nullif(raw_user_metadata->>'email_verified', '')::boolean as email_verified_bool,
              nullif(raw_user_metadata->>'phone_verified', '')::boolean as phone_verified_bool
       from public.users
     )
     update public.users u
     set raw_app_metadata = jsonb_set(u.raw_app_metadata, '{providers}', n.providers_json, true),
         raw_user_metadata = jsonb_set(
           jsonb_set(
             jsonb_set(u.raw_user_metadata, '{custom_claims}', n.custom_claims_json, true),
             '{email_verified}', to_jsonb(coalesce(n.email_verified_bool, false)), true
           ),
           '{phone_verified}', to_jsonb(coalesce(n.phone_verified_bool, false)), true
         )
     from normalized n
     where u.id = n.id;
     ```
   - After the JSON cleanup, invoke the trigger for historical data (e.g. `update public.users set raw_app_metadata = raw_app_metadata` in the same transaction) so every row gets normalized provider columns exactly once.
   - Guard the casts with `case` expressions if the stored strings are not valid JSON (fallback to `'{}'::jsonb`).
   - Populate new typed columns from the normalized metadata in the same migration.
2. **Service Layer Update**
   - Update the auth upsert function (Edge Function or iOS client) to map Supabase auth payload into structured columns + JSON.
   - Update `public.sync_user_from_auth()` to write `is_sso_user`, `is_anonymous`, and rely on the trigger to populate `provider_list`/`primary_provider` while still persisting clean JSON blobs.
     - Extend the insert/update column lists to cover the new typed flags and future timestamps (e.g. `email_confirmed_at` if added) so the function stays the single source of truth for auth-driven attributes.
     - Sanitize metadata pre-write: ensure `raw_app_metadata->'providers'` is an array (and replace other shapes with `'[]'::jsonb`), coerce `raw_user_metadata->'custom_claims'` into an object, and convert stringified booleans into real booleans before handing the payload to the trigger.
     - Keep existing display-name/avatar fallbacks, but explicitly avoid overriding non-null `display_name`/`avatar_url` with empty strings on update.
     - Let the trigger own `provider_list`/`primary_provider`; the function should only touch those columns indirectly by mutating `raw_app_metadata`.
   - Guarantee we send real arrays/objects by building from Swift structs instead of stringified JSON; prefer `JSONEncoder` (or the equivalent server-side encoder) and add a unit test that fails if the output includes quoted JSON strings.
3. **Regression Tests**
   - Add unit test for the upsert helper ensuring mixed provider lists persist as arrays and booleans stay booleans.
   - (Optional) Add a lightweight integration test hitting Supabase via local test harness to confirm schema expectations.
4. **Rollout**
   - Deploy migration to staging; run QA for sign-in/up flows.
   - Monitor logs for serialization errors; add alerting if JSON type check failures occur.
   - Communicate new columns to feature teams consuming `users` data.

## Risks & Mitigations
- **Existing Rows Failing Checks**: Run the backfill in the same migration before adding constraints; wrap in transaction.
- **Client Serialization Bugs**: Provide guard rails in the Swift helper (e.g. fail fast if metadata isn’t convertible) and add analytics during rollout.
- **Provider Drift**: Use generated column or trigger to keep `provider_list` synced when metadata changes.

## Open Questions & Recommendations
- **Additional profile fields (locale, timezone)**: We should defer adding these until a concrete feature needs them. Supabase auth doesn’t supply locale/timezone today, so we would need separate capture flows; maintaining nullable columns without a plan invites stale data. Keep this as a backlog item tied to personalization or scheduling features.
- **Expose `confirmed_at` / verification timestamps as columns**: Recommend adding a nullable `email_confirmed_at timestamptz` column populated from auth hooks. RLS policies and admin dashboards frequently need to filter on confirmation state; pulling from the auth schema at query time is awkward. This column can sync via trigger from `raw_user_metadata` or directly in the upsert payload.
- **Historical provider changes**: No downstream consumers currently require history, and we can reconstruct the active provider list from auth logs if absolutely necessary. Stick with overwriting provider metadata for now, but document the trade-off; if growth analytics later request provider timelines, we can introduce an audit table populated via database trigger.

---

## Completion Notes (2025-09-29)
- Migration `0015_user_metadata_normalization.sql` adds the new auth/provider columns, installs `public.normalize_user_provider_metadata()`, backfills existing rows, and enforces JSON shape constraints. Ran the same SQL against Supabase to normalize production data.
- `public.sync_user_from_auth()` now sanitizes incoming metadata, keeps typed flags in sync, and prefers `full_name`/`name` before falling back to email for `display_name`.
- iOS `SupabaseUserProfileSynchronizer` emits structured arrays/booleans/custom claims and populates the typed columns; unit coverage exercises stringified inputs to guard regressions.
- Live `public.users` rows verified: `provider_list` and `raw_app_metadata.providers` are lowercased arrays, booleans are true JSON booleans, and `primary_provider`/`email_confirmed_at` populate for existing accounts.
- Follow-up: none required unless we introduce additional profile fields (e.g., locale/timezone); future migrations should re-use the normalization trigger to stay consistent.
