-- Progress: Not yet implemented

-- Match status through its lifecycle
create type if not exists match_status as enum (
  'scheduled',
  'in_progress',
  'completed',
  'canceled'
);

-- Role of an official in a match
create type if not exists official_role as enum ('center', 'assistant_1', 'assistant_2', 'fourth');

-- Event types captured during a match timeline
create type if not exists match_event_type as enum (
  'period_start', 'period_end',
  'stoppage_start', 'stoppage_end',
  'goal', 'goal_overruled',
  'card_yellow', 'card_red', 'card_second_yellow',
  'penalty_awarded', 'penalty_scored', 'penalty_missed',
  'injury', 'substitution', 'note'
);

-- Self-assessment mood scale (example set; can evolve)
create type if not exists assessment_mood as enum ('calm', 'focused', 'stressed', 'fatigued');


