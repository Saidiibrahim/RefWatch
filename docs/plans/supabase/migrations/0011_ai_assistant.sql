-- Progress: Not yet implemented

-- Assistant feature: threads, messages, attachments, enums, indexes, RLS, triggers

-- Enum for AI message roles (Responses-compatible)
create type if not exists ai_message_role as enum ('system', 'user', 'assistant', 'tool');

-- Threads table (provider-neutral)
create table if not exists public.ai_threads (
  id uuid primary key,
  owner_id uuid not null references public.users(id) on delete cascade,
  title text,
  instructions text,
  default_model text,
  default_temperature double precision,
  metadata jsonb not null default '{}'::jsonb,
  prompt_tokens_total integer not null default 0,
  completion_tokens_total integer not null default 0,
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Messages table with multi-part content and usage
create table if not exists public.ai_messages (
  id uuid primary key,
  thread_id uuid not null references public.ai_threads(id) on delete cascade,
  role ai_message_role not null,
  content_text text,
  content_parts jsonb not null default '[]'::jsonb,
  provider_response_id text,
  tool_calls jsonb not null default '[]'::jsonb,
  tool_results jsonb not null default '[]'::jsonb,
  usage_input_tokens integer not null default 0,
  usage_output_tokens integer not null default 0,
  latency_ms integer,
  status text,
  error jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_attachments (
  id uuid primary key,
  message_id uuid not null references public.ai_messages(id) on delete cascade,
  storage_path text not null,
  content_type text,
  byte_size integer,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- Daily usage table
create table if not exists public.ai_usage_daily (
  owner_id uuid not null references public.users(id) on delete cascade,
  on_date date not null,
  model text not null,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  responses_count bigint not null default 0,
  last_updated_at timestamptz not null default now(),
  primary key (owner_id, on_date, model)
);

-- Indexes
create index if not exists idx_ai_threads_owner_activity on public.ai_threads(owner_id, last_activity_at desc);
create index if not exists idx_ai_messages_thread_time on public.ai_messages(thread_id, created_at asc);
create index if not exists idx_ai_threads_not_deleted on public.ai_threads(owner_id, last_activity_at desc) where deleted_at is null;

-- RLS policies
alter table public.ai_threads enable row level security;
create policy if not exists "ai_threads_own_rows" on public.ai_threads for all using (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
) with check (
  owner_id in (select id from public.users where clerk_user_id = current_setting('request.jwt.claim.sub', true))
);

alter table public.ai_messages enable row level security;
create policy if not exists "ai_messages_via_thread_owner" on public.ai_messages for all using (
  exists (
    select 1 from public.ai_threads t
    join public.users u on t.owner_id = u.id
    where t.id = ai_messages.thread_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
) with check (
  exists (
    select 1 from public.ai_threads t
    join public.users u on t.owner_id = u.id
    where t.id = ai_messages.thread_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

alter table public.ai_attachments enable row level security;
create policy if not exists "ai_attachments_via_message_owner" on public.ai_attachments for all using (
  exists (
    select 1 from public.ai_messages m
    join public.ai_threads t on m.thread_id = t.id
    join public.users u on t.owner_id = u.id
    where m.id = ai_attachments.message_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
) with check (
  exists (
    select 1 from public.ai_messages m
    join public.ai_threads t on m.thread_id = t.id
    join public.users u on t.owner_id = u.id
    where m.id = ai_attachments.message_id
      and u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
  )
);

-- Triggers
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger if not exists t_upd_ai_threads before update on public.ai_threads
for each row execute function set_updated_at();

create or replace function touch_ai_thread() returns trigger as $$
begin
  update public.ai_threads
     set last_activity_at = now(), updated_at = now()
   where id = new.thread_id;
  insert into public.ai_usage_daily(owner_id, on_date, model, input_tokens, output_tokens, responses_count, last_updated_at)
  select t.owner_id, (now() at time zone 'utc')::date, coalesce(t.default_model, 'unknown'), new.usage_input_tokens, new.usage_output_tokens, case when new.role = 'assistant' then 1 else 0 end, now()
  from public.ai_threads t where t.id = new.thread_id
  on conflict (owner_id, on_date, model)
  do update set
    input_tokens = public.ai_usage_daily.input_tokens + excluded.input_tokens,
    output_tokens = public.ai_usage_daily.output_tokens + excluded.output_tokens,
    responses_count = public.ai_usage_daily.responses_count + excluded.responses_count,
    last_updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger if not exists t_ai_messages_touch after insert on public.ai_messages
for each row execute function touch_ai_thread();


