import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import postgres from "https://deno.land/x/postgresjs@v3.4.3/mod.js";
const databaseUrl = Deno.env.get("SUPABASE_DB_URL");
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
if (!databaseUrl) {
  throw new Error("Missing SUPABASE_DB_URL environment variable");
}
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variable");
}
const sql = postgres(databaseUrl, {
  prepare: false,
  target_session_attrs: "read-write"
});
serve(async (req)=>{
  try {
    if (req.method !== "POST") {
      return jsonResponse({
        error: "not_found"
      }, 404);
    }
    // JWT verification is enabled at the edge function level, so Supabase
    // automatically validates the token before this code runs. We can extract
    // the user ID directly from the JWT payload using Supabase's helper.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      console.error("matches-ingest: Missing or invalid Authorization header");
      return jsonResponse({
        error: "unauthorized",
        message: "Missing or invalid Authorization header"
      }, 401);
    }

    // Create Supabase client for database operations (uses service role internally in edge functions)
    const supabase = createClient(supabaseUrl, supabaseAnonKey);

    // Extract user from the JWT token (already validated by platform)
    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);

    if (authError || !user) {
      console.error("matches-ingest: Failed to extract user from validated JWT", {
        error: authError?.message
      });
      return jsonResponse({
        error: "unauthorized",
        message: "Failed to extract user information"
      }, 401);
    }

    console.log("matches-ingest: Successfully authenticated user", {
      userId: user.id,
      email: user.email
    });
    const userId = user.id;
    const bundle = await parseRequest(req);
    const result = await ingestBundle(bundle, userId);
    console.log("matches-ingest: Successfully ingested match", {
      matchId: result.match_id,
      userId
    });
    return jsonResponse(result, 200);
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }
    console.error("matches-ingest: Unexpected error", error);
    return jsonResponse({
      error: "internal_error"
    }, 500);
  }
});
function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json"
    }
  });
}
async function parseRequest(req) {
  try {
    const payload = await req.json();
    if (!payload || typeof payload !== "object") {
      throw new Error("invalid payload");
    }
    return payload;
  } catch (error) {
    console.error("matches-ingest parse failed", error);
    throw jsonResponse({
      error: "invalid_payload"
    }, 422);
  }
}
function requireUuid(value, context) {
  if (typeof value !== "string" || uuidRegex.test(value) === false) {
    throw jsonResponse({
      error: "invalid_uuid",
      context
    }, 422);
  }
  return value;
}
function requireString(value, context) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw jsonResponse({
      error: "invalid_string",
      context
    }, 422);
  }
  return value;
}
function requireNumber(value, context) {
  if (typeof value !== "number" || Number.isFinite(value) === false) {
    throw jsonResponse({
      error: "invalid_number",
      context
    }, 422);
  }
  return value;
}
function optionalNumber(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}
const uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
async function ingestBundle(bundle, sessionUserId) {
  if (!bundle.match) {
    throw jsonResponse({
      error: "missing_match"
    }, 422);
  }
  const match = bundle.match;
  const matchId = requireUuid(match.id, "match.id");
  const ownerId = requireUuid(match.owner_id, "match.owner_id");
  // Normalize both UUIDs to lowercase for case-insensitive comparison
  const normalizedOwnerId = ownerId.toLowerCase();
  const normalizedSessionUserId = sessionUserId.toLowerCase();
  if (normalizedOwnerId !== normalizedSessionUserId) {
    console.error("matches-ingest ownership mismatch", {
      provided: normalizedOwnerId,
      expected: normalizedSessionUserId
    });
    throw jsonResponse({
      error: "forbidden",
      context: "owner_mismatch"
    }, 403);
  }
  const completedAt = requireString(match.completed_at, "match.completed_at");
  const startedAt = match.started_at ? requireString(match.started_at, "match.started_at") : completedAt;
  const homeName = requireString(match.home_team_name, "match.home_team_name");
  const awayName = requireString(match.away_team_name, "match.away_team_name");
  const numberOfPeriods = requireNumber(match.number_of_periods, "match.number_of_periods");
  const penaltyRounds = requireNumber(match.penalty_initial_rounds, "match.penalty_initial_rounds");
  const homeScore = requireNumber(match.home_score, "match.home_score");
  const awayScore = requireNumber(match.away_score, "match.away_score");
  const now = new Date().toISOString();
  try {
    const result = await sql.begin(async (tx)=>{
      const finalScoreJson = match.final_score ? tx.json(match.final_score) : null;
      const [row] = await tx`
        insert into public.matches (
          id, owner_id, scheduled_match_id, status, started_at, completed_at,
          duration_seconds, number_of_periods, regulation_minutes, half_time_minutes,
          competition_id, competition_name, venue_id, venue_name,
          home_team_id, home_team_name, away_team_id, away_team_name,
          extra_time_enabled, extra_time_half_minutes, penalties_enabled, penalty_initial_rounds,
          home_score, away_score, final_score, source_device_id
        ) values (
          ${matchId}::uuid,
          ${ownerId}::uuid,
          ${match.scheduled_match_id ?? null}::uuid,
          ${match.status ?? "completed"},
          ${startedAt}::timestamptz,
          ${completedAt}::timestamptz,
          ${optionalNumber(match.duration_seconds)},
          ${numberOfPeriods},
          ${optionalNumber(match.regulation_minutes)},
          ${optionalNumber(match.half_time_minutes)},
          ${match.competition_id ?? null}::uuid,
          ${match.competition_name ?? null},
          ${match.venue_id ?? null}::uuid,
          ${match.venue_name ?? null},
          ${match.home_team_id ?? null}::uuid,
          ${homeName},
          ${match.away_team_id ?? null}::uuid,
          ${awayName},
          ${match.extra_time_enabled ?? false},
          ${optionalNumber(match.extra_time_half_minutes)},
          ${match.penalties_enabled ?? false},
          ${penaltyRounds},
          ${homeScore},
          ${awayScore},
          ${finalScoreJson},
          ${match.source_device_id ?? null}
        )
        on conflict (id) do update set
          status = excluded.status,
          scheduled_match_id = excluded.scheduled_match_id,
          started_at = excluded.started_at,
          completed_at = excluded.completed_at,
          duration_seconds = excluded.duration_seconds,
          number_of_periods = excluded.number_of_periods,
          regulation_minutes = excluded.regulation_minutes,
          half_time_minutes = excluded.half_time_minutes,
          competition_id = excluded.competition_id,
          competition_name = excluded.competition_name,
          venue_id = excluded.venue_id,
          venue_name = excluded.venue_name,
          home_team_id = excluded.home_team_id,
          home_team_name = excluded.home_team_name,
          away_team_id = excluded.away_team_id,
          away_team_name = excluded.away_team_name,
          extra_time_enabled = excluded.extra_time_enabled,
          extra_time_half_minutes = excluded.extra_time_half_minutes,
          penalties_enabled = excluded.penalties_enabled,
          penalty_initial_rounds = excluded.penalty_initial_rounds,
          home_score = excluded.home_score,
          away_score = excluded.away_score,
          final_score = excluded.final_score,
          source_device_id = excluded.source_device_id,
          updated_at = timezone('utc', now())
        returning id, updated_at;
      `;
      await tx`delete from public.match_periods where match_id = ${matchId}::uuid`;
      if (Array.isArray(bundle.periods) && bundle.periods.length > 0) {
        const periodRows = bundle.periods.map((period, index)=>{
          const periodId = requireUuid(period.id, `periods[${index}].id`);
          const periodMatchId = requireUuid(period.match_id, `periods[${index}].match_id`);
          if (periodMatchId !== matchId) {
            throw jsonResponse({
              error: "invalid_period_match",
              index
            }, 422);
          }
          return {
            id: `${periodId}`,
            match_id: `${matchId}`,
            index: requireNumber(period.index, `periods[${index}].index`),
            regulation_seconds: requireNumber(period.regulation_seconds, `periods[${index}].regulation_seconds`),
            added_time_seconds: requireNumber(period.added_time_seconds ?? 0, `periods[${index}].added_time_seconds`),
            result: period.result ? tx.json(period.result) : null
          };
        });
        await tx`
          insert into public.match_periods ${tx(periodRows, 'id', 'match_id', 'index', 'regulation_seconds', 'added_time_seconds', 'result')}
        `;
      }
      await tx`delete from public.match_events where match_id = ${matchId}::uuid`;
      if (Array.isArray(bundle.events) && bundle.events.length > 0) {
        const eventRows = bundle.events.map((event, index)=>{
          const eventId = requireUuid(event.id, `events[${index}].id`);
          const eventMatchId = requireUuid(event.match_id, `events[${index}].match_id`);
          if (eventMatchId !== matchId) {
            throw jsonResponse({
              error: "invalid_event_match",
              index
            }, 422);
          }
          return {
            id: `${eventId}`,
            match_id: `${matchId}`,
            occurred_at: requireString(event.occurred_at, `events[${index}].occurred_at`),
            period_index: requireNumber(event.period_index, `events[${index}].period_index`),
            clock_seconds: requireNumber(event.clock_seconds, `events[${index}].clock_seconds`),
            match_time_label: requireString(event.match_time_label, `events[${index}].match_time_label`),
            event_type: requireString(event.event_type, `events[${index}].event_type`),
            payload: event.payload ? tx.json(event.payload) : null,
            team_side: event.team_side ?? null
          };
        });
        await tx`
          insert into public.match_events ${tx(eventRows, 'id', 'match_id', 'occurred_at', 'period_index', 'clock_seconds', 'match_time_label', 'event_type', 'payload', 'team_side')}
        `;
      }
      if (bundle.metrics) {
        const metrics = bundle.metrics;
        const metricsMatchId = requireUuid(metrics.match_id, 'metrics.match_id');
        if (metricsMatchId !== matchId) {
          throw jsonResponse({
            error: 'invalid_metrics_match'
          }, 422);
        }
        await tx`
          insert into public.match_metrics (
            match_id, owner_id, regulation_minutes, half_time_minutes, extra_time_minutes,
            penalties_enabled, total_goals, total_cards, total_penalties,
            yellow_cards, red_cards, home_cards, away_cards,
            home_substitutions, away_substitutions,
            penalties_scored, penalties_missed, avg_added_time_seconds, generated_at
          ) values (
            ${matchId}::uuid,
            ${ownerId}::uuid,
            ${optionalNumber(metrics.regulation_minutes)},
            ${optionalNumber(metrics.half_time_minutes)},
            ${optionalNumber(metrics.extra_time_minutes)},
            ${metrics.penalties_enabled ?? false},
            ${metrics.total_goals ?? 0},
            ${metrics.total_cards ?? 0},
            ${metrics.total_penalties ?? 0},
            ${metrics.yellow_cards ?? 0},
            ${metrics.red_cards ?? 0},
            ${metrics.home_cards ?? 0},
            ${metrics.away_cards ?? 0},
            ${metrics.home_substitutions ?? 0},
            ${metrics.away_substitutions ?? 0},
            ${metrics.penalties_scored ?? 0},
            ${metrics.penalties_missed ?? 0},
            ${metrics.avg_added_time_seconds ?? 0},
            ${now}::timestamptz
          )
          on conflict (match_id) do update set
            regulation_minutes = excluded.regulation_minutes,
            half_time_minutes = excluded.half_time_minutes,
            extra_time_minutes = excluded.extra_time_minutes,
            penalties_enabled = excluded.penalties_enabled,
            total_goals = excluded.total_goals,
            total_cards = excluded.total_cards,
            total_penalties = excluded.total_penalties,
            yellow_cards = excluded.yellow_cards,
            red_cards = excluded.red_cards,
            home_cards = excluded.home_cards,
            away_cards = excluded.away_cards,
            home_substitutions = excluded.home_substitutions,
            away_substitutions = excluded.away_substitutions,
            penalties_scored = excluded.penalties_scored,
            penalties_missed = excluded.penalties_missed,
            avg_added_time_seconds = excluded.avg_added_time_seconds,
            generated_at = excluded.generated_at
        `;
      } else {
        await tx`delete from public.match_metrics where match_id = ${matchId}::uuid`;
      }
      return row;
    });
    // Ensure updated_at is always an ISO8601 string
    const updatedAt = result.updated_at instanceof Date
      ? result.updated_at.toISOString()
      : typeof result.updated_at === "string"
        ? result.updated_at
        : new Date(result.updated_at).toISOString();

    const response = {
      match_id: result.id,
      updated_at: updatedAt
    };

    console.log("matches-ingest: Returning response", { response });
    return response;
  } catch (error) {
    if (error instanceof Response) {
      throw error;
    }
    console.error("matches-ingest transaction failed", error);
    throw jsonResponse({
      error: "ingest_failed"
    }, 500);
  }
}
