BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL timezone = 'UTC';
SET LOCAL search_path = pg_catalog, public, auth, extensions;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '45s';

WITH
expected_tables(table_name) AS (
  VALUES
    ('ai_attachments'), ('ai_messages'), ('ai_threads'), ('ai_usage_daily'),
    ('coaches'), ('coaching_sessions'), ('competitions'),
    ('feedback_attachments'), ('feedback_items'), ('feedback_threads'),
    ('match_assessments'), ('match_events'), ('match_metrics'),
    ('match_officials'), ('match_periods'), ('match_reports'), ('matches'),
    ('pages'), ('reference_competitions'),
    ('reference_disciplinary_codes'), ('reference_disciplinary_rules'),
    ('reference_teams'), ('resource_shares'), ('scheduled_matches'),
    ('team_members'), ('team_officials'), ('team_tags'), ('teams'),
    ('trend_snapshots'), ('user_devices'), ('users'), ('venues'),
    ('wellness_check_ins'), ('workout_events'),
    ('workout_intensity_profile'), ('workout_presets'), ('workout_segments'),
    ('workout_session_metrics'), ('workout_sessions')
),
actual_tables AS (
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
),
catalog_gate AS (
  SELECT
    (SELECT count(*) FROM expected_tables) = 39
      AND NOT EXISTS (
        SELECT table_name FROM expected_tables
        EXCEPT
        SELECT table_name FROM actual_tables
      )
      AND NOT EXISTS (
        SELECT table_name FROM actual_tables
        EXCEPT
        SELECT table_name FROM expected_tables
      ) AS exact
),
table_stats AS (
  SELECT * FROM (
    SELECT 'ai_attachments' AS table_name, count(*)::int AS row_count, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') AS row_sha256 FROM (SELECT to_jsonb(t)::text AS row_json FROM public.ai_attachments t) s
    UNION ALL SELECT 'ai_messages', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.ai_messages t) s
    UNION ALL SELECT 'ai_threads', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.ai_threads t) s
    UNION ALL SELECT 'ai_usage_daily', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.ai_usage_daily t) s
    UNION ALL SELECT 'coaches', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.coaches t) s
    UNION ALL SELECT 'coaching_sessions', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.coaching_sessions t) s
    UNION ALL SELECT 'competitions', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.competitions t) s
    UNION ALL SELECT 'feedback_attachments', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.feedback_attachments t) s
    UNION ALL SELECT 'feedback_items', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.feedback_items t) s
    UNION ALL SELECT 'feedback_threads', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.feedback_threads t) s
    UNION ALL SELECT 'match_assessments', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.match_assessments t) s
    UNION ALL SELECT 'match_events', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.match_events t) s
    UNION ALL SELECT 'match_metrics', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.match_metrics t) s
    UNION ALL SELECT 'match_officials', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.match_officials t) s
    UNION ALL SELECT 'match_periods', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.match_periods t) s
    UNION ALL SELECT 'match_reports', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.match_reports t) s
    UNION ALL SELECT 'matches', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.matches t) s
    UNION ALL SELECT 'pages', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.pages t) s
    UNION ALL SELECT 'reference_competitions', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.reference_competitions t) s
    UNION ALL SELECT 'reference_disciplinary_codes', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.reference_disciplinary_codes t) s
    UNION ALL SELECT 'reference_disciplinary_rules', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.reference_disciplinary_rules t) s
    UNION ALL SELECT 'reference_teams', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.reference_teams t) s
    UNION ALL SELECT 'resource_shares', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.resource_shares t) s
    UNION ALL SELECT 'scheduled_matches', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.scheduled_matches t) s
    UNION ALL SELECT 'team_members', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.team_members t) s
    UNION ALL SELECT 'team_officials', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.team_officials t) s
    UNION ALL SELECT 'team_tags', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.team_tags t) s
    UNION ALL SELECT 'teams', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.teams t) s
    UNION ALL SELECT 'trend_snapshots', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.trend_snapshots t) s
    UNION ALL SELECT 'user_devices', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.user_devices t) s
    UNION ALL SELECT 'users', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.users t) s
    UNION ALL SELECT 'venues', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.venues t) s
    UNION ALL SELECT 'wellness_check_ins', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.wellness_check_ins t) s
    UNION ALL SELECT 'workout_events', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.workout_events t) s
    UNION ALL SELECT 'workout_intensity_profile', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.workout_intensity_profile t) s
    UNION ALL SELECT 'workout_presets', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.workout_presets t) s
    UNION ALL SELECT 'workout_segments', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.workout_segments t) s
    UNION ALL SELECT 'workout_session_metrics', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.workout_session_metrics t) s
    UNION ALL SELECT 'workout_sessions', count(*)::int, encode(extensions.digest(convert_to(coalesce(string_agg(length(row_json)::text || ':' || row_json, '' ORDER BY row_json), ''), 'UTF8'), 'sha256'), 'hex') FROM (SELECT to_jsonb(t)::text AS row_json FROM public.workout_sessions t) s
  ) rows_by_table
),
rls_contract AS (
  SELECT
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    c.relforcerowsecurity AS force_rls,
    count(p.polname)::int AS policy_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_policy p ON p.polrelid = c.oid
  WHERE n.nspname = 'public' AND c.relkind = 'r'
  GROUP BY c.relname, c.relrowsecurity, c.relforcerowsecurity
),
auth_users_safe AS (
  SELECT jsonb_build_object(
    'id', id::text,
    'email', lower(email),
    'created_at', created_at,
    'updated_at', updated_at,
    'email_confirmed_at', email_confirmed_at,
    'last_sign_in_at', last_sign_in_at,
    'banned_until', banned_until,
    'deleted_at', deleted_at,
    'is_sso_user', is_sso_user,
    'is_anonymous', is_anonymous
  )::text AS safe_row
  FROM auth.users
),
auth_identities_safe AS (
  SELECT jsonb_build_object(
    'id', id::text,
    'user_id', user_id::text,
    'provider', provider,
    'provider_id', provider_id,
    'email', lower(email),
    'created_at', created_at,
    'updated_at', updated_at,
    'last_sign_in_at', last_sign_in_at
  )::text AS safe_row
  FROM auth.identities
),
auth_only AS (
  SELECT au.id, lower(au.email) AS email
  FROM auth.users au
  LEFT JOIN public.users pu ON pu.id = au.id
  WHERE pu.id IS NULL
),
auth_only_owned AS (
  SELECT
    (SELECT count(*) FROM public.ai_threads t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.ai_usage_daily t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.coaches t JOIN auth_only a ON a.id = t.user_id)
    + (SELECT count(*) FROM public.coaching_sessions t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.competitions t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.feedback_threads t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.match_assessments t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.match_metrics t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.match_officials t JOIN auth_only a ON a.id = t.user_id)
    + (SELECT count(*) FROM public.matches t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.pages t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.resource_shares t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.scheduled_matches t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.teams t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.trend_snapshots t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.user_devices t JOIN auth_only a ON a.id = t.user_id)
    + (SELECT count(*) FROM public.venues t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.wellness_check_ins t JOIN auth_only a ON a.id = t.owner_id)
    + (SELECT count(*) FROM public.workout_presets t JOIN auth_only a ON a.id = t.created_by)
    + (SELECT count(*) FROM public.workout_sessions t JOIN auth_only a ON a.id = t.owner_id)
    AS owned_row_count
),
schema_contract AS (
  SELECT jsonb_build_object(
    'columns', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'table', table_name, 'column', column_name, 'ordinal', ordinal_position,
        'data_type', data_type, 'udt_schema', udt_schema, 'udt_name', udt_name,
        'nullable', is_nullable, 'default', column_default,
        'identity', is_identity, 'generated', is_generated
      ) ORDER BY table_name, ordinal_position), '[]'::jsonb)
      FROM information_schema.columns WHERE table_schema = 'public'
    ),
    'constraints', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'table', c.relname, 'name', con.conname, 'type', con.contype,
        'definition', pg_get_constraintdef(con.oid, true),
        'deferrable', con.condeferrable, 'deferred', con.condeferred,
        'validated', con.convalidated
      ) ORDER BY c.relname, con.conname), '[]'::jsonb)
      FROM pg_constraint con
      JOIN pg_class c ON c.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
    ),
    'indexes', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'table', tablename, 'name', indexname, 'definition', indexdef
      ) ORDER BY tablename, indexname), '[]'::jsonb)
      FROM pg_indexes WHERE schemaname = 'public'
    ),
    'enums', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'schema', n.nspname, 'type', t.typname, 'label', e.enumlabel,
        'order', e.enumsortorder
      ) ORDER BY n.nspname, t.typname, e.enumsortorder), '[]'::jsonb)
      FROM pg_type t
      JOIN pg_namespace n ON n.oid = t.typnamespace
      JOIN pg_enum e ON e.enumtypid = t.oid
      WHERE n.nspname IN ('public', 'auth')
    ),
    'rls', (
      SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.table_name), '[]'::jsonb)
      FROM rls_contract r
    ),
    'policies', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'table', tablename, 'name', policyname, 'permissive', permissive,
        'roles', roles, 'command', cmd, 'using', qual, 'check', with_check
      ) ORDER BY tablename, policyname), '[]'::jsonb)
      FROM pg_policies WHERE schemaname = 'public'
    )
  ) AS value
),
result AS (
  SELECT jsonb_build_object(
    'status', 'candidate',
    'final', false,
    'eligible_for_import', false,
    'writes_quiesced', false,
    'final_export_complete', false,
    'source', 'supabase-mcp-sanitized-readback',
    'source_project_ref', 'muwuzfbtmqwvwacqnofc',
    'database', current_database(),
    'database_role', current_user,
    'transaction_isolation', current_setting('transaction_isolation'),
    'read_only', current_setting('transaction_read_only') = 'on',
    'timezone', current_setting('timezone'),
    'captured_at_utc', to_char(transaction_timestamp(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'statement_at_utc', to_char(statement_timestamp(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'completed_at_utc', to_char(clock_timestamp(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'transaction_snapshot', txid_current_snapshot()::text,
    'observed_wal_lsn', pg_current_wal_lsn()::text,
    'catalog_exact_39', g.exact,
    'catalog_guard', 1 / g.exact::int,
    'total_public_rows', (SELECT sum(row_count)::int FROM table_stats),
    'table_stats', (
      SELECT jsonb_agg(to_jsonb(s) ORDER BY s.table_name) FROM table_stats s
    ),
    'public_data_contract_sha256', encode(extensions.digest(convert_to((
      SELECT jsonb_agg(to_jsonb(s) ORDER BY s.table_name)::text FROM table_stats s
    ), 'UTF8'), 'sha256'), 'hex'),
    'schema_contract_sha256', encode(extensions.digest(convert_to((SELECT value::text FROM schema_contract), 'UTF8'), 'sha256'), 'hex'),
    'rls_contract_sha256', encode(extensions.digest(convert_to((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.table_name)::text FROM rls_contract r
    ), 'UTF8'), 'sha256'), 'hex'),
    'rls_contract', (
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.table_name) FROM rls_contract r
    ),
    'rls_disabled_tables', (
      SELECT coalesce(jsonb_agg(table_name ORDER BY table_name), '[]'::jsonb)
      FROM rls_contract WHERE NOT rls_enabled
    ),
    'auth_user_count', (SELECT count(*)::int FROM auth.users),
    'public_user_count', (SELECT count(*)::int FROM public.users),
    'auth_identity_count', (SELECT count(*)::int FROM auth.identities),
    'auth_only_count', (SELECT count(*)::int FROM auth_only),
    'auth_only_matches_approved_testing_email', (
      SELECT count(*) = 1 AND bool_and(email = 'testing@refwatch.com') FROM auth_only
    ),
    'auth_only_owned_row_count', (SELECT owned_row_count::int FROM auth_only_owned),
    'auth_user_ids_sha256', encode(extensions.digest(convert_to(coalesce((SELECT string_agg(id::text, ',' ORDER BY id::text) FROM auth.users), ''), 'UTF8'), 'sha256'), 'hex'),
    'public_user_ids_sha256', encode(extensions.digest(convert_to(coalesce((SELECT string_agg(id::text, ',' ORDER BY id::text) FROM public.users), ''), 'UTF8'), 'sha256'), 'hex'),
    'auth_users_safe_sha256', encode(extensions.digest(convert_to(coalesce((SELECT string_agg(length(safe_row)::text || ':' || safe_row, '' ORDER BY safe_row) FROM auth_users_safe), ''), 'UTF8'), 'sha256'), 'hex'),
    'auth_identities_safe_sha256', encode(extensions.digest(convert_to(coalesce((SELECT string_agg(length(safe_row)::text || ':' || safe_row, '' ORDER BY safe_row) FROM auth_identities_safe), ''), 'UTF8'), 'sha256'), 'hex'),
    'auth_users_safe_columns', jsonb_build_array('id', 'email', 'created_at', 'updated_at', 'email_confirmed_at', 'last_sign_in_at', 'banned_until', 'deleted_at', 'is_sso_user', 'is_anonymous'),
    'auth_identities_safe_columns', jsonb_build_array('id', 'user_id', 'provider', 'provider_id', 'email', 'created_at', 'updated_at', 'last_sign_in_at'),
    'auth_sensitive_fields_exported', false,
    'rls_bypass_qualification', 'Snapshot executed through a privileged provider connector; RLS state is inventoried but does not filter the source export contract.'
  ) AS candidate_snapshot
  FROM catalog_gate g
)
SELECT candidate_snapshot FROM result;

COMMIT;
