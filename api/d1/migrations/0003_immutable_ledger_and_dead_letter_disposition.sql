ALTER TABLE mutation_ledger_dead_letters
ADD COLUMN disposition TEXT NOT NULL DEFAULT 'quarantined'
CHECK(disposition IN ('quarantined', 'stale'));

CREATE TRIGGER mutation_ledger_events_no_update
BEFORE UPDATE ON mutation_ledger_events
BEGIN
  SELECT RAISE(ABORT, 'mutation ledger events are immutable');
END;

CREATE TRIGGER mutation_ledger_events_no_delete
BEFORE DELETE ON mutation_ledger_events
BEGIN
  SELECT RAISE(ABORT, 'mutation ledger events are immutable');
END;

CREATE TRIGGER mutation_ledger_dead_letters_no_update
BEFORE UPDATE ON mutation_ledger_dead_letters
BEGIN
  SELECT RAISE(ABORT, 'mutation ledger dead letters are immutable');
END;

CREATE TRIGGER mutation_ledger_dead_letters_no_delete
BEFORE DELETE ON mutation_ledger_dead_letters
BEGIN
  SELECT RAISE(ABORT, 'mutation ledger dead letters are immutable');
END;
