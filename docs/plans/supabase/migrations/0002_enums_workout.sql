-- Progress: Not yet implemented

-- Workout state aligned with RefWorkoutCore.WorkoutSession.State
create type if not exists workout_state as enum ('planned', 'active', 'paused', 'ended', 'aborted');

-- Workout kind aligned with RefWorkoutCore.WorkoutKind
create type if not exists workout_kind as enum (
  'outdoorRun', 'outdoorWalk', 'indoorRun', 'indoorCycle', 'strength', 'mobility', 'refereeDrill', 'custom'
);

-- Workout segment purpose aligned with RefWorkoutCore.WorkoutSegment.Purpose
create type if not exists workout_segment_purpose as enum ('warmup', 'work', 'recovery', 'cooldown', 'free');

-- Core workout metric kinds and units
create type if not exists workout_metric_kind as enum (
  'distance', 'duration', 'averagePace', 'averageSpeed', 'averageHeartRate', 'maximumHeartRate', 'calories', 'elevationGain', 'cadence', 'power', 'perceivedExertion'
);
create type if not exists workout_metric_unit as enum (
  'meters', 'kilometers', 'seconds', 'minutes', 'minutesPerKilometer', 'kilometersPerHour', 'beatsPerMinute', 'kilocalories', 'metersClimbed', 'stepsPerMinute', 'watts', 'ratingOfPerceivedExertion'
);


