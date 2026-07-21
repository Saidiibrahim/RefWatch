-- Sanitized, read-only classification of inactive mutation-ledger history.
-- Historical frozen/archived rows are informational; open or capture-enforced
-- epochs remain launch blockers.
select jsonb_build_object(
  'observed_at_utc',
    to_char(
      statement_timestamp() at time zone 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
    ),
  'database_name', current_database(),
  'database_branch_id', (
    select branch_id
    from runtime_database_markers
    where environment = 'production'
    order by marker
    limit 1
  ),
  'runtime_marker', (
    select marker
    from runtime_database_markers
    where environment = 'production'
    order by marker
    limit 1
  ),
  'total_epoch_count', (select count(*) from mutation_ledger_epochs),
  'preparing_epoch_count', (
    select count(*) from mutation_ledger_epochs where status = 'preparing'
  ),
  'open_epoch_count', (
    select count(*) from mutation_ledger_epochs where status = 'open'
  ),
  'frozen_epoch_count', (
    select count(*) from mutation_ledger_epochs where status = 'frozen'
  ),
  'archived_epoch_count', (
    select count(*) from mutation_ledger_epochs where status = 'archived'
  ),
  'capture_enforced_epoch_count', (
    select count(*) from mutation_ledger_epochs where capture_enforced
  ),
  'entity_revision_count', (select count(*) from mutation_entity_revisions),
  'outbox_event_count', (select count(*) from mutation_outbox_events),
  'outbox_delivery_count', (select count(*) from mutation_outbox_deliveries)
) as greenfield_ledger_readback;
