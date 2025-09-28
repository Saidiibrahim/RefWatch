# Clerk to Supabase Auth Migration: Fixing RLS Policies and Database Schema

## Overview

This plan addresses critical issues discovered during the migration from Clerk authentication to Supabase Auth in the RefZone iOS app. The primary issue is that database Row Level Security (RLS) policies are still configured for Clerk authentication, causing repeated policy violations when the app attempts to sync data.

## Current Issues Identified

### 🚨 Critical: RLS Policy Violations
- **Symptom**: Repeated `Supabase schedule push failed` errors with "new row violates row-level security policy for table 'scheduled_matches'"
- **Root Cause**: RLS policies still check for Clerk user IDs (`clerk_user_id`) while the app now uses Supabase Auth (`auth.uid()`)
- **Impact**: Complete sync failure, no data persistence to Supabase
- **Observed Behaviour**: `SupabaseScheduleRepository` keeps re-queueing the failed upsert (`RefZoneiOS/Core/Platform/Supabase/SupabaseScheduleRepository.swift:246-268`), spamming the log with retry noise while the user sees no in-app error. Classify 401/403/RLS failures as non-retryable, mark sync as blocked, and surface actionable UI feedback.

### 📊 Database Schema Inconsistencies
- **Custom `users` table**: Still references `clerk_user_id` field
- **Foreign key dependencies**: All tables reference obsolete `public.users(id)` instead of `auth.users.id`
- **Authentication mismatch**: iOS app correctly uses Supabase Auth, but database expects Clerk tokens
- **Key Insight**: `public.users` underpins nearly every FK; rather than dropping it outright, re-purpose it as a profiles table keyed by `auth.users.id` or swap each FK directly to `auth.users` once the data is backfilled.

### ✅ iOS Implementation Status
- **Supabase Auth implementation**: ✅ Working correctly
- **Apple Sign In flow**: ✅ Functional
- **Google Sign In setup**: ✅ Code ready (not yet tested)
- **Token management**: ✅ Proper session handling
- **Logging**: Functions client currently logs the anon-key fallback every refresh; once auth policies are patched we should downgrade that message to avoid obscuring real failures.

## Migration Plan

### Phase 1: Update RLS Policies (Critical Fix)

**Priority**: 🔴 HIGH - This single change will resolve the immediate sync failures

#### 1.1 Update `scheduled_matches` RLS Policy
```sql
-- Replace existing policy
DROP POLICY IF EXISTS "scheduled_matches_own_rows" ON public.scheduled_matches;

CREATE POLICY "scheduled_matches_own_rows" ON public.scheduled_matches
  FOR ALL USING (
    owner_id = auth.uid()
  )
  WITH CHECK (
    owner_id = auth.uid()
  );
```

- **Client Follow-up**: teach the schedule sync layer to stop re-queuing pushes when Supabase returns an RLS/PostgREST error and surface an in-app recovery hint (e.g. “Identity sync incomplete, tap to retry after policies update”).

#### 1.2 Update All Other Table RLS Policies
Apply similar changes to all tables with user-scoped policies:
- `teams`
- `competitions`
- `venues`
- `matches`
- `match_events`
- `match_assessments`
- All other user-owned resources

**Pattern**: Replace `clerk_user_id = current_setting('request.jwt.claim.sub', true)` with `auth.uid()`

### Phase 2: Schema Modernization (Recommended)

#### 2.1 Re-key and Enrich `public.users`
Keep the domain-level `public.users` table but align it with Supabase Auth and mirror key metadata so every FK remains stable and the app has a single profile source:

```sql
-- Drop Clerk metadata and enforce that the primary key matches auth.users.id
ALTER TABLE public.users
  DROP COLUMN IF EXISTS clerk_user_id,
  ALTER COLUMN id DROP DEFAULT,
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS email_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_sign_in_at timestamptz,
  ADD COLUMN IF NOT EXISTS raw_app_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS raw_user_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now(),
  ADD CONSTRAINT users_auth_fk FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
```

#### 2.2 Update Foreign Key Constraints
```sql
-- Example for scheduled_matches table
ALTER TABLE public.scheduled_matches
DROP CONSTRAINT scheduled_matches_owner_id_fkey;

ALTER TABLE public.scheduled_matches
ADD CONSTRAINT scheduled_matches_owner_id_fkey
FOREIGN KEY (owner_id) REFERENCES public.users(id);
```

- **Backfill Checklist**: Before swapping constraints, create a job/migration that maps existing `public.users.id` values to their `auth.users.id` counterparts (for legacy Clerk rows, pull the UUID from the new Supabase session created via Sign in with Apple).

#### 2.3 Data Migration & Automation
```sql
-- Migrate existing user data to reference Supabase Auth users
-- This step requires careful mapping of existing users to new auth.users entries
```
- Backfill plan: match legacy rows on email, update `id` to the Supabase auth UUID, hydrate new profile fields, and seed timestamps.
- Automation: add a post-auth trigger/function that upserts into `public.users` after each new sign-in and refreshes metadata (email, display name, avatar, provider list).

### Phase 3: Testing & Validation

#### 3.1 RLS Policy Testing
- [ ] Test `scheduled_matches` sync functionality
- [ ] Verify user data scoping works correctly
- [ ] Test with multiple user accounts
- [ ] Confirm the iOS client surfaces a clear error state when RLS rejects a write (prevents silent infinite retries)

#### 3.2 Authentication Flow Testing
- [ ] Apple Sign In end-to-end test
- [ ] Google Sign In implementation and testing
- [ ] Session persistence across app restarts
- [ ] Sign out functionality

#### 3.3 Data Integrity Verification
- [ ] Existing data remains accessible to correct users
- [ ] New data creates with proper owner associations
- [ ] Cross-user data isolation works correctly

### Phase 4: Supabase Auth → Public Users Sync

#### 4.1 Client responsibilities
- [x] Add a `SupabaseUserProfileSynchronizer` helper under `RefZoneiOS/Core/Platform/Supabase/` that can fetch or upsert `public.users` rows using the current session's UUID. Shape the payload with `id`, `email`, `display_name`, `avatar_url`, `email_verified`, `last_sign_in_at`, `raw_app_metadata`, `raw_user_metadata`, and timestamps.
- [x] Inject the synchronizer into `SupabaseAuthController` so `refreshState(using:)` calls `await synchronizer.syncIfNeeded(session:)` after successful sign-in/restore. Ensure failures are logged and surfaced so repositories can retry once the row exists.
- [x] Cover the helper with unit tests (e.g. `SupabaseUserProfileSynchronizerTests`) to validate payload translation and error handling.
- [x] Update app entry points (e.g. `RefZoneiOSApp`, previews) to pass the synchronizer dependency.

#### 4.2 Database automation
- [x] Add a `public.sync_user_from_auth()` security-definer function that upserts into `public.users` when supplied an `auth.users` row (mirroring the columns listed above).
- [x] Create `AFTER INSERT`/`AFTER UPDATE` triggers on `auth.users` that invoke the function so new or updated GoTrue users automatically populate `public.users`.
- [ ] Optionally add an `AFTER DELETE` trigger to cascade cleanup of `public.users` (respecting `ON DELETE CASCADE` for dependent tables).
- [x] Ship the function + triggers in a migration and document rollout steps so other environments receive the automation.

## Implementation Priority

### Immediate (Today)
1. **Update RLS policies** for `scheduled_matches` table
2. **Test sync functionality** to confirm fix

### Short-term (This Week)
1. **Update all remaining RLS policies** across all tables
2. **Complete Apple Sign In testing**
3. **Implement Google Sign In testing**
4. **Re-key & enrich `public.users`** (apply Phase 2.1 schema changes, mirror auth metadata, add timestamps)
5. **Update schedule sync retry handling + logging** so RLS failures surface once instead of looping silently

### Medium-term (Next Sprint)
1. **Data migration & automation** (backfill existing users, add triggers/functions to keep metadata fresh)
2. **Performance optimization** of new auth patterns
3. **Tighten Supabase client logging** (downgrade anon-key fallback log once auth session is in place) to keep signal-to-noise ratio high

## Risk Assessment

### Low Risk
- **RLS policy updates**: Simple SQL changes, reversible
- **Testing auth flows**: Non-destructive validation

### Medium Risk
- **Foreign key constraint changes**: Requires careful sequencing
- **Data migration**: Potential for data loss if not executed properly

### High Risk
- **Re-keying users without backup**: Backfill mistakes could orphan child rows; take snapshots before altering IDs

## Success Criteria

- [ ] Zero RLS policy violation errors in logs
- [ ] Successful `scheduled_matches` sync to Supabase
- [ ] Apple Sign In works end-to-end with data persistence
- [ ] Google Sign In functional (when tested)
- [ ] Clean, maintainable database schema
- [ ] No remaining Clerk dependencies
- [ ] Simulator/Xcode logs show at most a single `Supabase schedule push failed` entry before policies are fixed (no infinite retry spam)

## Rollback Plan

1. **RLS Policy Rollback**: Revert to Clerk-based policies if issues arise
2. **Schema Rollback**: Restore custom users table if foreign key changes cause issues
3. **Data Backup**: Full database backup before any destructive operations

## Notes

- The iOS implementation is already correctly configured for Supabase Auth
- The main blocker is database-side RLS policy configuration
- This migration will significantly simplify the authentication architecture
- Consider this an opportunity to clean up any other Clerk remnants in the codebase
- Keep `public.users` as the domain profile table; just ensure `id` mirrors `auth.users.id` so existing foreign keys remain valid and RLS stays simple (`owner_id = auth.uid()`).
