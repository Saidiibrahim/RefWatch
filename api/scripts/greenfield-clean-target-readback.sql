-- Sanitized, read-only production greenfield baseline query.
-- The operator must bind the returned receipt to the reviewed PlanetScale
-- organization/database/branch outside SQL; no credential values are selected.
select jsonb_build_object(
  'database_name', current_database(),
  'database_role', current_user,
  'runtime_markers', (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'marker', marker,
          'branch_id', branch_id,
          'environment', environment
        )
        order by marker
      ),
      '[]'::jsonb
    )
    from runtime_database_markers
  ),
  'deterministic_seed', jsonb_build_object(
    'reference_competitions_count',
      (select count(*) from reference_competitions),
    'reference_competitions_business_md5',
      (
        select md5(
          string_agg(
            jsonb_build_object(
              'id', id,
              'code', code,
              'name', name,
              'season_year', season_year,
              'federation', federation,
              'tier', tier,
              'gender', gender,
              'source_url', source_url,
              'source_published_at', source_published_at
            )::text,
            ''
            order by id
          )
        )
        from reference_competitions
      ),
    'reference_teams_count',
      (select count(*) from reference_teams),
    'reference_teams_business_md5',
      (
        select md5(
          string_agg(
            jsonb_build_object(
              'id', id,
              'competition_id', competition_id,
              'name', name,
              'short_name', short_name,
              'reference_key', reference_key,
              'season_year', season_year,
              'source_url', source_url,
              'source_name_note', source_name_note
            )::text,
            ''
            order by id
          )
        )
        from reference_teams
      ),
    'reference_disciplinary_codes_count',
      (select count(*) from reference_disciplinary_codes),
    'reference_disciplinary_rules_count',
      (select count(*) from reference_disciplinary_rules),
    'global_workout_presets_count',
      (select count(*) from workout_presets where created_by is null)
  ),
  'clean_target_inventory', jsonb_build_object(
    'app_users', (select count(*) from app_users),
    'identity_reconciliation_receipts',
      (select count(*) from identity_reconciliation_receipts),
    'identity_reconciliation_activations',
      (select count(*) from identity_reconciliation_activations),
    'identity_reconciliation_legacy_mappings',
      (select count(*) from identity_reconciliation_legacy_mappings),
    'clerk_user_deletion_tombstones',
      (select count(*) from clerk_user_deletion_tombstones),
    'clerk_webhook_delivery_receipts',
      (select count(*) from clerk_webhook_delivery_receipts),
    'user_devices', (select count(*) from user_devices),
    'teams', (select count(*) from teams),
    'team_members', (select count(*) from team_members),
    'team_officials', (select count(*) from team_officials),
    'team_tags', (select count(*) from team_tags),
    'competitions', (select count(*) from competitions),
    'venues', (select count(*) from venues),
    'scheduled_matches', (select count(*) from scheduled_matches),
    'matches', (select count(*) from matches),
    'match_periods', (select count(*) from match_periods),
    'match_events', (select count(*) from match_events),
    'match_metrics', (select count(*) from match_metrics),
    'match_assessments', (select count(*) from match_assessments),
    'pages', (select count(*) from pages),
    'user_owned_workout_presets',
      (select count(*) from workout_presets where created_by is not null),
    'workout_sessions', (select count(*) from workout_sessions),
    'idempotency_keys', (select count(*) from idempotency_keys),
    'ai_threads', (select count(*) from ai_threads),
    'ai_messages', (select count(*) from ai_messages),
    'ai_attachments', (select count(*) from ai_attachments),
    'ai_usage_daily', (select count(*) from ai_usage_daily)
  )
) as greenfield_readback;
