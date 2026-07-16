CREATE TABLE mutation_ledger_events (
  event_id TEXT PRIMARY KEY NOT NULL,
  event_sequence INTEGER NOT NULL,
  epoch_id TEXT NOT NULL,
  mutation_group_id TEXT NOT NULL,
  group_ordinal INTEGER NOT NULL,
  schema_version INTEGER NOT NULL,
  source_kind TEXT NOT NULL,
  worker_version_id TEXT NOT NULL,
  content_digest TEXT NOT NULL,
  encryption_key_id TEXT NOT NULL,
  encryption_nonce TEXT NOT NULL,
  encrypted_envelope TEXT NOT NULL,
  materialized_at_utc TEXT NOT NULL,
  UNIQUE(epoch_id, event_sequence),
  UNIQUE(mutation_group_id, group_ordinal),
  CHECK(schema_version = 1),
  CHECK(length(content_digest) = 64)
);

CREATE INDEX mutation_ledger_events_epoch_sequence_idx
ON mutation_ledger_events(epoch_id, event_sequence);

CREATE TABLE mutation_ledger_probes (
  probe_receipt_id TEXT PRIMARY KEY NOT NULL,
  event_id TEXT NOT NULL REFERENCES mutation_ledger_events(event_id) ON DELETE RESTRICT,
  observed_content_digest TEXT NOT NULL,
  observed_at_utc TEXT NOT NULL
);
