-- 006: Daily Aggregates
-- Pre-computed daily rollups per user for fast dashboard queries

create table if not exists public.daily_aggregates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  sessions integer default 0,
  events integer default 0,
  tool_uses integer default 0,
  total_duration_ms bigint default 0,
  tool_breakdown jsonb default '{}', -- { "Read": 42, "Write": 15, ... }
  hourly_distribution jsonb default '[]', -- [0, 0, 3, 5, ...] (24 entries)
  stop_reasons jsonb default '{}', -- { "end_turn": 5, "tool_use": 10 }
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, date)
);

create index idx_daily_agg_user_date on public.daily_aggregates(user_id, date desc);

create trigger daily_aggregates_updated_at
  before update on public.daily_aggregates
  for each row execute procedure public.update_updated_at();

-- RLS
alter table public.daily_aggregates enable row level security;

create policy "Users can view own aggregates"
  on public.daily_aggregates for select
  using (auth.uid() = user_id);

create policy "Service role full access aggregates"
  on public.daily_aggregates for all
  using (auth.role() = 'service_role');

-- Function to upsert daily aggregate from events
create or replace function public.update_daily_aggregate(
  p_user_id uuid,
  p_date date
) returns void as $$
declare
  v_sessions integer;
  v_events integer;
  v_tool_uses integer;
  v_total_duration bigint;
  v_tool_breakdown jsonb;
  v_hourly jsonb;
  v_stop_reasons jsonb;
begin
  -- Count sessions
  select count(distinct session_id) into v_sessions
  from public.events
  where user_id = p_user_id
    and timestamp::date = p_date;

  -- Count events
  select count(*) into v_events
  from public.events
  where user_id = p_user_id
    and timestamp::date = p_date;

  -- Count tool uses
  select count(*) into v_tool_uses
  from public.events
  where user_id = p_user_id
    and timestamp::date = p_date
    and event_type in ('tool_use', 'tool_result');

  -- Total duration
  select coalesce(sum(duration_ms), 0) into v_total_duration
  from public.events
  where user_id = p_user_id
    and timestamp::date = p_date
    and duration_ms is not null;

  -- Tool breakdown
  select coalesce(jsonb_object_agg(tool_name, cnt), '{}')
  into v_tool_breakdown
  from (
    select tool_name, count(*) as cnt
    from public.events
    where user_id = p_user_id
      and timestamp::date = p_date
      and tool_name is not null
    group by tool_name
  ) t;

  -- Hourly distribution
  select coalesce(
    jsonb_agg(coalesce(hour_count, 0) order by h),
    '[]'
  ) into v_hourly
  from generate_series(0, 23) as h
  left join (
    select extract(hour from timestamp)::integer as hour, count(*) as hour_count
    from public.events
    where user_id = p_user_id
      and timestamp::date = p_date
    group by extract(hour from timestamp)
  ) ec on ec.hour = h;

  -- Stop reasons
  select coalesce(jsonb_object_agg(reason, cnt), '{}')
  into v_stop_reasons
  from (
    select data->>'stop_reason' as reason, count(*) as cnt
    from public.events
    where user_id = p_user_id
      and timestamp::date = p_date
      and event_type in ('assistant_stop', 'session_end')
      and data->>'stop_reason' is not null
    group by data->>'stop_reason'
  ) sr;

  -- Upsert
  insert into public.daily_aggregates (
    user_id, date, sessions, events, tool_uses,
    total_duration_ms, tool_breakdown, hourly_distribution, stop_reasons
  ) values (
    p_user_id, p_date, v_sessions, v_events, v_tool_uses,
    v_total_duration, v_tool_breakdown, v_hourly, v_stop_reasons
  )
  on conflict (user_id, date) do update set
    sessions = excluded.sessions,
    events = excluded.events,
    tool_uses = excluded.tool_uses,
    total_duration_ms = excluded.total_duration_ms,
    tool_breakdown = excluded.tool_breakdown,
    hourly_distribution = excluded.hourly_distribution,
    stop_reasons = excluded.stop_reasons,
    updated_at = now();
end;
$$ language plpgsql security definer;
