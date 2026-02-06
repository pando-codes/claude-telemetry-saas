-- 007: Utility functions for analytics queries

-- Get overview stats for a user within a date range
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

-- Get team overview stats
create or replace function public.get_team_overview_stats(
  p_team_id uuid,
  p_from date,
  p_to date
) returns json as $$
declare
  result json;
begin
  select json_build_object(
    'total_sessions', coalesce(sum(da.sessions), 0),
    'total_events', coalesce(sum(da.events), 0),
    'total_tool_uses', coalesce(sum(da.tool_uses), 0),
    'active_members', count(distinct da.user_id) filter (where da.sessions > 0),
    'total_members', (select count(*) from public.team_members where team_id = p_team_id),
    'avg_session_duration_min', coalesce(
      round(avg(case when da.sessions > 0 then da.total_duration_ms::numeric / da.sessions / 60000 end), 1),
      0
    )
  ) into result
  from public.daily_aggregates da
  inner join public.team_members tm on tm.user_id = da.user_id
  where tm.team_id = p_team_id
    and da.date between p_from and p_to;

  return result;
end;
$$ language plpgsql security definer;

-- Get top tools for a user
create or replace function public.get_top_tools(
  p_user_id uuid,
  p_from date,
  p_to date,
  p_limit integer default 20
) returns json as $$
declare
  result json;
begin
  select coalesce(json_agg(t), '[]') into result
  from (
    select
      tool_name,
      count(*) as count,
      round(avg(duration_ms)) as avg_duration_ms,
      percentile_cont(0.5) within group (order by duration_ms) as p50_duration_ms,
      percentile_cont(0.99) within group (order by duration_ms) as p99_duration_ms
    from public.events
    where user_id = p_user_id
      and timestamp::date between p_from and p_to
      and tool_name is not null
      and event_type = 'tool_result'
    group by tool_name
    order by count desc
    limit p_limit
  ) t;

  return result;
end;
$$ language plpgsql security definer;
