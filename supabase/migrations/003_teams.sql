-- 003: Teams, Members, Invitations

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger teams_updated_at
  before update on public.teams
  for each row execute procedure public.update_updated_at();

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz default now(),
  unique(team_id, user_id)
);

create index idx_team_members_team on public.team_members(team_id);
create index idx_team_members_user on public.team_members(user_id);

create table if not exists public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  email text not null,
  role text not null default 'member' check (role in ('admin', 'member')),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'expired')),
  invited_by uuid not null references auth.users(id),
  created_at timestamptz default now(),
  expires_at timestamptz default now() + interval '7 days'
);

create index idx_team_invitations_email on public.team_invitations(email);
create index idx_team_invitations_team on public.team_invitations(team_id);

-- RLS
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invitations enable row level security;

-- Teams: visible to members
create policy "Team members can view team"
  on public.teams for select
  using (
    id in (select team_id from public.team_members where user_id = auth.uid())
  );

create policy "Authenticated users can create teams"
  on public.teams for insert
  with check (auth.uid() = created_by);

create policy "Team owners/admins can update team"
  on public.teams for update
  using (
    id in (
      select team_id from public.team_members
      where user_id = auth.uid() and role in ('owner', 'admin')
    )
  );

create policy "Team owners can delete team"
  on public.teams for delete
  using (
    id in (
      select team_id from public.team_members
      where user_id = auth.uid() and role = 'owner'
    )
  );

-- Team members: visible to team members
create policy "Team members can view members"
  on public.team_members for select
  using (
    team_id in (select team_id from public.team_members where user_id = auth.uid())
  );

create policy "Team owners/admins can manage members"
  on public.team_members for all
  using (
    team_id in (
      select team_id from public.team_members
      where user_id = auth.uid() and role in ('owner', 'admin')
    )
  );

-- Invitations: visible to inviter + invitee
create policy "Team admins can manage invitations"
  on public.team_invitations for all
  using (
    team_id in (
      select team_id from public.team_members
      where user_id = auth.uid() and role in ('owner', 'admin')
    )
  );

create policy "Invitees can view own invitations"
  on public.team_invitations for select
  using (
    email = (select email from auth.users where id = auth.uid())
  );

-- Service role
create policy "Service role full access teams"
  on public.teams for all using (auth.role() = 'service_role');
create policy "Service role full access team_members"
  on public.team_members for all using (auth.role() = 'service_role');
create policy "Service role full access team_invitations"
  on public.team_invitations for all using (auth.role() = 'service_role');
