-- Auto-create monthly partitions for the events table
-- This runs on the 25th of each month to create next month's partition

-- Enable pg_cron extension
create extension if not exists pg_cron;

-- Function to create monthly partitions
create or replace function create_monthly_partition()
returns void as $$
declare
  next_month date;
  partition_name text;
  start_date text;
  end_date text;
begin
  next_month := date_trunc('month', now()) + interval '1 month';
  partition_name := 'events_' || to_char(next_month, 'YYYY_MM');
  start_date := to_char(next_month, 'YYYY-MM-DD');
  end_date := to_char(next_month + interval '1 month', 'YYYY-MM-DD');

  -- Only create if doesn't exist
  if not exists (
    select 1 from pg_class where relname = partition_name
  ) then
    execute format(
      'create table %I partition of events for values from (%L) to (%L)',
      partition_name, start_date, end_date
    );
    raise notice 'Created partition: %', partition_name;
  end if;
end;
$$ language plpgsql;

-- Schedule: run on the 25th of each month at midnight UTC
select cron.schedule(
  'create-monthly-partition',
  '0 0 25 * *',
  'select create_monthly_partition()'
);
