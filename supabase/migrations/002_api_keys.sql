-- 002: API Keys
-- Stores hashed API keys for plugin authentication (ct_live_ prefix)

create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  key_hash text not null unique,
  key_prefix text not null, -- e.g. "ct_live_xxxx"
  scopes text[] not null default '{}',
  rate_limit_tier text not null default 'standard',
  last_used_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz default now()
);

create index idx_api_keys_user_id on public.api_keys(user_id);
create index idx_api_keys_key_hash on public.api_keys(key_hash);

-- RLS
alter table public.api_keys enable row level security;

create policy "Users can view own api keys"
  on public.api_keys for select
  using (auth.uid() = user_id);

create policy "Users can create own api keys"
  on public.api_keys for insert
  with check (auth.uid() = user_id);

create policy "Users can update own api keys"
  on public.api_keys for update
  using (auth.uid() = user_id);

create policy "Users can delete own api keys"
  on public.api_keys for delete
  using (auth.uid() = user_id);

-- Service role needs full access for API key validation
create policy "Service role full access to api keys"
  on public.api_keys for all
  using (auth.role() = 'service_role');
