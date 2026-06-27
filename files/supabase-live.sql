-- ============================================================
--  Dig Pro — Live spectating add-on
--  Run this once in Supabase → SQL Editor (in addition to supabase-setup.sql).
--  It lets a host broadcast an in-progress game, and anyone with the code
--  watch it update in real time (read-only).
-- ============================================================

create table if not exists live_games (
  id uuid primary key default gen_random_uuid(),
  host uuid not null references auth.users on delete cascade,
  code text unique not null,
  data jsonb not null,
  active boolean default true,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

alter table live_games enable row level security;

-- Anyone (incl. signed-out viewers using the public key) can READ a live game.
-- The share code is the access mechanism; only the host can write.
drop policy if exists live_read on live_games;
create policy live_read on live_games for select using (true);

drop policy if exists live_host_insert on live_games;
create policy live_host_insert on live_games for insert with check (host = auth.uid());

drop policy if exists live_host_update on live_games;
create policy live_host_update on live_games for update using (host = auth.uid()) with check (host = auth.uid());

drop policy if exists live_host_delete on live_games;
create policy live_host_delete on live_games for delete using (host = auth.uid());

-- Enable Realtime so viewers receive live updates (ignore if already added).
do $$ begin
  alter publication supabase_realtime add table live_games;
exception when duplicate_object then null; end $$;

-- Optional housekeeping: an index for quick code lookups.
create index if not exists live_games_code_idx on live_games (code);
