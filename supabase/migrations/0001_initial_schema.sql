create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 2 and 40),
  avatar_color text not null default 'ff5af28a',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'football-data',
  provider_team_id text not null,
  name text not null,
  short_name text not null,
  country_code text,
  badge_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_team_id)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'football-data',
  provider_match_id text not null,
  competition text not null default 'FIFA World Cup',
  season int not null default 2026,
  stage text not null default 'Group stage',
  group_name text,
  venue text,
  home_team_id uuid not null references public.teams(id),
  away_team_id uuid not null references public.teams(id),
  kickoff_at timestamptz not null,
  status text not null default 'scheduled' check (status in ('scheduled', 'live', 'finished', 'postponed')),
  home_score int check (home_score >= 0),
  away_score int check (away_score >= 0),
  raw_payload jsonb not null default '{}'::jsonb,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_match_id)
);

create table if not exists public.predictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  home_score int not null check (home_score between 0 and 20),
  away_score int not null check (away_score between 0 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, match_id)
);

create table if not exists public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 40),
  owner_id uuid references public.profiles(id) on delete set null,
  invite_code text unique,
  is_global boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.league_members (
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);

create table if not exists public.prediction_scores (
  prediction_id uuid primary key references public.predictions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  points int not null check (points in (0, 1, 3)),
  exact boolean not null default false,
  calculated_at timestamptz not null default now()
);

create table if not exists public.provider_request_log (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  endpoint text not null,
  status_code int,
  success boolean not null default false,
  request_count int not null default 1,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists matches_kickoff_at_idx on public.matches(kickoff_at);
create index if not exists predictions_user_match_idx on public.predictions(user_id, match_id);
create index if not exists prediction_scores_user_idx on public.prediction_scores(user_id);
create index if not exists league_members_user_idx on public.league_members(user_id);

insert into public.leagues (id, name, invite_code, is_global)
values ('00000000-0000-0000-0000-000000000001', 'Global', null, true)
on conflict (id) do nothing;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists teams_touch_updated_at on public.teams;
create trigger teams_touch_updated_at
before update on public.teams
for each row execute function public.touch_updated_at();

drop trigger if exists matches_touch_updated_at on public.matches;
create trigger matches_touch_updated_at
before update on public.matches
for each row execute function public.touch_updated_at();

drop trigger if exists predictions_touch_updated_at on public.predictions;
create trigger predictions_touch_updated_at
before update on public.predictions
for each row execute function public.touch_updated_at();

create or replace function public.create_profile(display_name text, avatar_color text default 'ff5af28a')
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_row public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.profiles (id, display_name, avatar_color)
  values (auth.uid(), trim(create_profile.display_name), create_profile.avatar_color)
  on conflict (id) do update
    set display_name = excluded.display_name,
        avatar_color = excluded.avatar_color,
        updated_at = now()
  returning * into profile_row;

  insert into public.league_members (league_id, user_id)
  values ('00000000-0000-0000-0000-000000000001', auth.uid())
  on conflict do nothing;

  return profile_row;
end;
$$;

create or replace function public.score_prediction(
  predicted_home int,
  predicted_away int,
  actual_home int,
  actual_away int
)
returns int
language sql
immutable
as $$
  select case
    when predicted_home = actual_home and predicted_away = actual_away then 3
    when sign(predicted_home - predicted_away) = sign(actual_home - actual_away) then 1
    else 0
  end;
$$;

create or replace function public.upsert_prediction(match_id uuid, home_score int, away_score int)
returns public.predictions
language plpgsql
security definer
set search_path = public
as $$
declare
  match_row public.matches;
  prediction_row public.predictions;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into match_row
  from public.matches
  where id = upsert_prediction.match_id;

  if match_row.id is null then
    raise exception 'Match not found';
  end if;

  if match_row.kickoff_at <= now() or match_row.status <> 'scheduled' then
    raise exception 'Predictions lock at kickoff';
  end if;

  insert into public.predictions (user_id, match_id, home_score, away_score)
  values (auth.uid(), upsert_prediction.match_id, upsert_prediction.home_score, upsert_prediction.away_score)
  on conflict (user_id, match_id) do update
    set home_score = excluded.home_score,
        away_score = excluded.away_score,
        updated_at = now()
  returning * into prediction_row;

  return prediction_row;
end;
$$;

create or replace function public.recalculate_match_scores(match_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  match_row public.matches;
  affected_count int;
begin
  select * into match_row
  from public.matches
  where id = recalculate_match_scores.match_id;

  if match_row.id is null then
    raise exception 'Match not found';
  end if;

  if match_row.status <> 'finished' or match_row.home_score is null or match_row.away_score is null then
    return 0;
  end if;

  insert into public.prediction_scores (prediction_id, user_id, match_id, points, exact, calculated_at)
  select
    p.id,
    p.user_id,
    p.match_id,
    public.score_prediction(p.home_score, p.away_score, match_row.home_score, match_row.away_score),
    p.home_score = match_row.home_score and p.away_score = match_row.away_score,
    now()
  from public.predictions p
  where p.match_id = match_row.id
  on conflict (prediction_id) do update
    set points = excluded.points,
        exact = excluded.exact,
        calculated_at = now();

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;

create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i int;
begin
  for i in 1..6 loop
    code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return code;
end;
$$;

create or replace function public.create_league(league_name text)
returns table (
  id uuid,
  name text,
  member_count int,
  rank int,
  total_players int,
  points int,
  is_global boolean,
  invite_code text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  league_row public.leagues;
  code text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  loop
    code := public.generate_invite_code();
    exit when not exists (select 1 from public.leagues l where l.invite_code = code);
  end loop;

  insert into public.leagues (name, owner_id, invite_code, is_global)
  values (trim(create_league.league_name), auth.uid(), code, false)
  returning * into league_row;

  insert into public.league_members (league_id, user_id)
  values (league_row.id, auth.uid());

  return query
  select league_row.id, league_row.name, 1, 1, 1, 0, league_row.is_global, league_row.invite_code;
end;
$$;

create or replace function public.join_league(invite_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  league_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select l.id into league_id
  from public.leagues l
  where l.invite_code = upper(trim(join_league.invite_code));

  if league_id is null then
    raise exception 'League not found';
  end if;

  insert into public.league_members (league_id, user_id)
  values (league_id, auth.uid())
  on conflict do nothing;
end;
$$;

create or replace view public.user_score_totals as
select
  p.id as user_id,
  coalesce(sum(ps.points), 0)::int as points,
  coalesce(sum(case when ps.exact then 1 else 0 end), 0)::int as exact_scores
from public.profiles p
left join public.prediction_scores ps on ps.user_id = p.id
group by p.id;

create or replace function public.get_leaderboard(league_id uuid)
returns table (
  user_id uuid,
  display_name text,
  rank int,
  points int,
  exact_scores int,
  is_current_user boolean
)
language sql
security definer
set search_path = public
as $$
  with allowed as (
    select exists (
      select 1
      from public.league_members lm
      where lm.league_id = get_leaderboard.league_id
        and lm.user_id = auth.uid()
    ) as can_read
  ),
  scores as (
    select
      p.id as user_id,
      p.display_name,
      coalesce(ust.points, 0)::int as points,
      coalesce(ust.exact_scores, 0)::int as exact_scores
    from public.league_members lm
    join public.profiles p on p.id = lm.user_id
    left join public.user_score_totals ust on ust.user_id = p.id
    cross join allowed
    where lm.league_id = get_leaderboard.league_id
      and allowed.can_read
  )
  select
    scores.user_id,
    scores.display_name,
    (rank() over (order by scores.points desc, scores.exact_scores desc))::int as rank,
    scores.points,
    scores.exact_scores,
    scores.user_id = auth.uid() as is_current_user
  from scores
  order by rank, lower(scores.display_name);
$$;

create or replace function public.get_my_leagues()
returns table (
  id uuid,
  name text,
  member_count int,
  rank int,
  total_players int,
  points int,
  is_global boolean,
  invite_code text
)
language sql
security definer
set search_path = public
as $$
  with my_scores as (
    select coalesce(points, 0)::int as points
    from public.user_score_totals
    where user_id = auth.uid()
  ),
  counts as (
    select league_id, count(*)::int as member_count
    from public.league_members
    group by league_id
  ),
  ranked as (
    select
      lm.league_id,
      lm.user_id,
      (rank() over (
        partition by lm.league_id
        order by coalesce(ust.points, 0) desc, coalesce(ust.exact_scores, 0) desc
      ))::int as rank
    from public.league_members lm
    left join public.user_score_totals ust on ust.user_id = lm.user_id
  )
  select
    l.id,
    l.name,
    coalesce(c.member_count, 0),
    coalesce(r.rank, 0),
    coalesce(c.member_count, 0),
    coalesce((select points from my_scores), 0),
    l.is_global,
    case when l.owner_id = auth.uid() then l.invite_code else null end
  from public.league_members mine
  join public.leagues l on l.id = mine.league_id
  left join counts c on c.league_id = l.id
  left join ranked r on r.league_id = l.id and r.user_id = auth.uid()
  where mine.user_id = auth.uid()
  order by l.is_global desc, l.created_at;
$$;

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.matches enable row level security;
alter table public.predictions enable row level security;
alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
alter table public.prediction_scores enable row level security;
alter table public.provider_request_log enable row level security;

create policy "profiles are readable by authenticated users"
on public.profiles for select to authenticated using (true);

create policy "users can update their own profile"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "teams are readable"
on public.teams for select to authenticated using (true);

create policy "matches are readable"
on public.matches for select to authenticated using (true);

create policy "users can read their own predictions"
on public.predictions for select to authenticated using (user_id = auth.uid());

create policy "users can insert unlocked own predictions"
on public.predictions for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.matches m
    where m.id = match_id
      and m.kickoff_at > now()
      and m.status = 'scheduled'
  )
);

create policy "users can update unlocked own predictions"
on public.predictions for update to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.matches m
    where m.id = match_id
      and m.kickoff_at > now()
      and m.status = 'scheduled'
  )
);

create policy "members can read their leagues"
on public.leagues for select to authenticated
using (
  is_global
  or exists (
    select 1 from public.league_members lm
    where lm.league_id = id
      and lm.user_id = auth.uid()
  )
);

create policy "members can read league memberships"
on public.league_members for select to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.league_members mine
    where mine.league_id = public.league_members.league_id
      and mine.user_id = auth.uid()
  )
);

create policy "users can read their own scores"
on public.prediction_scores for select to authenticated using (user_id = auth.uid());

create policy "provider logs are service-role only"
on public.provider_request_log for all to service_role using (true) with check (true);

revoke all on function public.recalculate_match_scores(uuid) from anon, authenticated;
grant execute on function public.recalculate_match_scores(uuid) to service_role;

grant execute on function public.create_profile(text, text) to authenticated;
grant execute on function public.upsert_prediction(uuid, int, int) to authenticated;
grant execute on function public.create_league(text) to authenticated;
grant execute on function public.join_league(text) to authenticated;
grant execute on function public.get_leaderboard(uuid) to authenticated;
grant execute on function public.get_my_leagues() to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table public.matches;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'predictions'
  ) then
    alter publication supabase_realtime add table public.predictions;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'prediction_scores'
  ) then
    alter publication supabase_realtime add table public.prediction_scores;
  end if;
end $$;
