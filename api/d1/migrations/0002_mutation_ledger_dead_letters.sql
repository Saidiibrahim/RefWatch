CREATE TABLE mutation_ledger_dead_letters (
  dead_letter_id TEXT PRIMARY KEY NOT NULL,
  event_id TEXT NOT NULL,
  lease_generation INTEGER NOT NULL,
  source_queue TEXT NOT NULL,
  dlq_consumer_attempt INTEGER NOT NULL,
  received_at_utc TEXT NOT NULL,
  UNIQUE(event_id, lease_generation),
  CHECK(lease_generation > 0),
  CHECK(dlq_consumer_attempt > 0)
);

CREATE INDEX mutation_ledger_dead_letters_event_idx
ON mutation_ledger_dead_letters(event_id);
