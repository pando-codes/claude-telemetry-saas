-- 009: Add agent_calls tracking to daily aggregates and overview stats

-- Add column
alter table public.daily_aggregates
  add column if not exists agent_calls integer default 0;

-- Update daily aggregate function to count agent calls
create or replace function public.update_daily_aggregate(
  p_user_id uuid,
  p_date date
) returns void as $$
declare
  v_sessions integer;
  v_events integer;
  v_tool_uses integer;
  v_agent_calls integer;
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

  -- Count agent calls
  select count(*) into v_agent_calls
  from public.events
  where user_id = p_user_id
    and timestamp::date = p_date
    and event_type = 'subagent_stop';

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
    user_id, date, sessions, events, tool_uses, agent_calls,
    total_duration_ms, tool_breakdown, hourly_distribution, stop_reasons
  ) values (
    p_user_id, p_date, v_sessions, v_events, v_tool_uses, v_agent_calls,
    v_total_duration, v_tool_breakdown, v_hourly, v_stop_reasons
  )
  on conflict (user_id, date) do update set
    sessions = excluded.sessions,
    events = excluded.events,
    tool_uses = excluded.tool_uses,
    agent_calls = excluded.agent_calls,
    total_duration_ms = excluded.total_duration_ms,
    tool_breakdown = excluded.tool_breakdown,
    hourly_distribution = excluded.hourly_distribution,
    stop_reasons = excluded.stop_reasons,
    updated_at = now();
end;
$$ language plpgsql security definer;

-- Update overview stats to include agent calls
create or replace function public.get_overview_stats(
  p_user_id uuid,
  p_from date,
  p_to date
) returns json as $$
declare
  result json;
begin
  select json_build_object(
    'total_sessions', coalesce(sum(sessions), 0),
    'total_events', coalesce(sum(events), 0),
    'total_tool_uses', coalesce(sum(tool_uses), 0),
    'total_agent_calls', coalesce(sum(agent_calls), 0),
    'active_days', count(*) filter (where sessions > 0),
    'avg_session_duration_min', coalesce(
      round(avg(case when sessions > 0 then total_duration_ms::numeric / sessions / 60000 end), 1),
      0
    ),
    'avg_tools_per_session', coalesce(
      round(avg(case when sessions > 0 then tool_uses::numeric / sessions end), 1),
      0
    )
  ) into result
  from public.daily_aggregates
  where user_id = p_user_id
    and date between p_from and p_to;

  return result;
end;
$$ language plpgsql security definer;
