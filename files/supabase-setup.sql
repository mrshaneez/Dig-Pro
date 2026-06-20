-- ============================================================
--  Dig Pro — Supabase setup
--  Run this once in your Supabase project: SQL Editor → New query → paste → Run.
--  It creates the tables, the security rules (Row Level Security), and two
--  helper functions. The security rules guarantee that a signed-in user can
--  only see another user's games when they share a league.
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- tables ----------
create table if not exists profiles (
  id uuid primary key references auth.users on delete cascade,
  email text,
  display_name text,
  created_at timestamptz default now()
);

create table if not exists rules (               -- one default-rules blob per user
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists players (             -- a user's saved player list
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references auth.users on delete cascade,
  name text not null,
  suit int default 0,
  created_at timestamptz default now()
);

create table if not exists leagues (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references auth.users on delete cascade,
  name text not null,
  join_code text unique not null,
  created_at timestamptz default now()
);

create table if not exists league_members (
  league_id uuid references leagues on delete cascade,
  user_id uuid references auth.users on delete cascade,
  joined_at timestamptz default now(),
  primary key (league_id, user_id)
);

create table if not exists games (               -- finished games; league_id null = private
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references auth.users on delete cascade,
  league_id uuid references leagues on delete set null,
  data jsonb not null,
  played_at timestamptz default now()
);

-- ---------- membership helper (SECURITY DEFINER avoids RLS recursion) ----------
create or replace function is_member(p_league uuid, p_user uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from league_members m
                 where m.league_id = p_league and m.user_id = p_user);
$$;

-- ---------- enable Row Level Security ----------
alter table profiles        enable row level security;
alter table rules           enable row level security;
alter table players         enable row level security;
alter table leagues         enable row level security;
alter table league_members  enable row level security;
alter table games           enable row level security;

-- profiles: only yourself
create policy profiles_self on profiles for all
  using (id = auth.uid()) with check (id = auth.uid());

-- rules: only yourself
create policy rules_self on rules for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- players: only the owner
create policy players_owner on players for all
  using (owner = auth.uid()) with check (owner = auth.uid());

-- leagues: members (or owner) can read; only the owner can change
create policy leagues_read   on leagues for select using (owner = auth.uid() or is_member(id, auth.uid()));
create policy leagues_insert on leagues for insert with check (owner = auth.uid());
create policy leagues_update on leagues for update using (owner = auth.uid()) with check (owner = auth.uid());
create policy leagues_delete on leagues for delete using (owner = auth.uid());

-- league_members: members can read the roster; you may add/remove only yourself
create policy lm_read        on league_members for select using (is_member(league_id, auth.uid()));
create policy lm_self_insert on league_members for insert with check (user_id = auth.uid());
create policy lm_self_delete on league_members for delete using (user_id = auth.uid());

-- games: you can read your own AND any game in a league you belong to.
--        you can only write/delete your own.
create policy games_read   on games for select
  using (owner = auth.uid() or (league_id is not null and is_member(league_id, auth.uid())));
create policy games_insert on games for insert with check (owner = auth.uid());
create policy games_update on games for update using (owner = auth.uid()) with check (owner = auth.uid());
create policy games_delete on games for delete using (owner = auth.uid());

-- ---------- join a league by its code ----------
create or replace function join_league(p_code text)
returns leagues language plpgsql security definer as $$
declare lg leagues;
begin
  select * into lg from leagues where join_code = upper(trim(p_code));
  if lg.id is null then raise exception 'No league with that code'; end if;
  insert into league_members(league_id, user_id) values (lg.id, auth.uid())
    on conflict do nothing;
  return lg;
end; $$;

-- ---------- triggers: auto profile + auto-add league owner as member ----------
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles(id, email) values (new.id, new.email) on conflict do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

create or replace function handle_new_league()
returns trigger language plpgsql security definer as $$
begin
  insert into league_members(league_id, user_id) values (new.id, new.owner) on conflict do nothing;
  return new;
end; $$;
drop trigger if exists on_league_created on leagues;
create trigger on_league_created after insert on leagues
  for each row execute function handle_new_league();
