-- 005: Sessions table
-- Denormalized session summaries, upserted during ingestion

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  session_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_ms integer,
  event_count integer default 0,
  tool_count integer default 0,
  stop_reason text,
  git_branch text,
  working_directory text,
  model text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(session_id, user_id)
);

create index idx_sessions_user on public.sessions(user_id);
create index idx_sessions_user_started on public.sessions(user_id, started_at desc);
create index idx_sessions_session_id on public.sessions(session_id);

create trigger sessions_updated_at
  before update on public.sessions
  for each row execute procedure public.update_updated_at();

-- RLS
alter table public.sessions enable row level security;

create policy "Users can view own sessions"
  on public.sessions for select
  using (auth.uid() = user_id);

create policy "Service role full access sessions"
  on public.sessions for all
  using (auth.role() = 'service_role');
