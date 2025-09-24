-- Progress: Implemented

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type
    WHERE typname = 'ai_message_role'
      AND typnamespace = 'public'::regnamespace
  ) THEN
    EXECUTE 'CREATE TYPE public.ai_message_role AS ENUM (''system'', ''user'', ''assistant'', ''tool'')';
  END IF;
END $$;

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

create index if not exists idx_ai_threads_owner_activity on public.ai_threads(owner_id, last_activity_at desc);
create index if not exists idx_ai_messages_thread_time on public.ai_messages(thread_id, created_at asc);
create index if not exists idx_ai_threads_not_deleted on public.ai_threads(owner_id, last_activity_at desc) where deleted_at is null;

alter table public.ai_threads enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_attachments enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'ai_threads'
      AND policyname = 'ai_threads_own_rows'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "ai_threads_own_rows" ON public.ai_threads
        FOR ALL USING (
          owner_id IN (
            SELECT id FROM public.users
            WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        )
        WITH CHECK (
          owner_id IN (
            SELECT id FROM public.users
            WHERE clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        );
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'ai_messages'
      AND policyname = 'ai_messages_via_thread_owner'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "ai_messages_via_thread_owner" ON public.ai_messages
        FOR ALL USING (
          EXISTS (
            SELECT 1
            FROM public.ai_threads t
            JOIN public.users u ON t.owner_id = u.id
            WHERE t.id = ai_messages.thread_id
              AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM public.ai_threads t
            JOIN public.users u ON t.owner_id = u.id
            WHERE t.id = ai_messages.thread_id
              AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        );
    $policy$;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'ai_attachments'
      AND policyname = 'ai_attachments_via_message_owner'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "ai_attachments_via_message_owner" ON public.ai_attachments
        FOR ALL USING (
          EXISTS (
            SELECT 1
            FROM public.ai_messages m
            JOIN public.ai_threads t ON m.thread_id = t.id
            JOIN public.users u ON t.owner_id = u.id
            WHERE m.id = ai_attachments.message_id
              AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM public.ai_messages m
            JOIN public.ai_threads t ON m.thread_id = t.id
            JOIN public.users u ON t.owner_id = u.id
            WHERE m.id = ai_attachments.message_id
              AND u.clerk_user_id = current_setting('request.jwt.claim.sub', true)
          )
        );
    $policy$;
  END IF;
END $$;

create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_upd_ai_threads'
      AND tgrelid = 'public.ai_threads'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_upd_ai_threads BEFORE UPDATE ON public.ai_threads
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()';
  END IF;
END $$;

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

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 't_ai_messages_touch'
      AND tgrelid = 'public.ai_messages'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER t_ai_messages_touch AFTER INSERT ON public.ai_messages
             FOR EACH ROW EXECUTE FUNCTION touch_ai_thread()';
  END IF;
END $$;
