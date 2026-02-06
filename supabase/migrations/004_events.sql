-- 004: Events table — partitioned by month
-- High-volume table. Monthly partitions for efficient queries and retention.

create table if not exists public.events (
  id uuid default gen_random_uuid(),
  user_id uuid not null,
  session_id text not null,
  event_type text not null,
  timestamp timestamptz not null,
  seq integer not null default 0,
  tool_name text,
  duration_ms integer,
  data jsonb default '{}',
  created_at timestamptz default now(),
  primary key (id, created_at)
) partition by range (created_at);

-- Create partitions for current and next 6 months
do $$
declare
  start_date date;
  end_date date;
  partition_name text;
begin
  for i in 0..6 loop
    start_date := date_trunc('month', current_date) + (i || ' months')::interval;
    end_date := start_date + '1 month'::interval;
    partition_name := 'events_' || to_char(start_date, 'YYYY_MM');

    execute format(
      'create table if not exists public.%I partition of public.events
       for values from (%L) to (%L)',
      partition_name, start_date, end_date
    );
  end loop;
end $$;

-- Indexes on each partition are auto-inherited, but we create them on the parent
create index idx_events_user_session on public.events(user_id, session_id);
create index idx_events_user_timestamp on public.events(user_id, timestamp);
create index idx_events_session on public.events(session_id);
create index idx_events_event_type on public.events(event_type);

-- RLS
alter table public.events enable row level security;

create policy "Users can view own events"
  on public.events for select
  using (auth.uid() = user_id);

-- No direct insert by users — only via service role (API key ingestion)
create policy "Service role can insert events"
  on public.events for insert
  with check (auth.role() = 'service_role');

create policy "Service role can read all events"
  on public.events for select
  using (auth.role() = 'service_role');

-- Auto-create future partitions (call via pg_cron monthly)
create or replace function public.create_events_partition()
returns void as $$
declare
  start_date date;
  end_date date;
  partition_name text;
begin
  -- Create partition for 3 months ahead
  for i in 0..3 loop
    start_date := date_trunc('month', current_date) + (i || ' months')::interval;
    end_date := start_date + '1 month'::interval;
    partition_name := 'events_' || to_char(start_date, 'YYYY_MM');

    execute format(
      'create table if not exists public.%I partition of public.events
       for values from (%L) to (%L)',
      partition_name, start_date, end_date
    );
  end loop;
end;
$$ language plpgsql;
