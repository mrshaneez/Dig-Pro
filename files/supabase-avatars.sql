-- ============================================================
--  Dig Pro — Player photos (avatars)
--  Run once in Supabase → SQL Editor (optional — photos work locally
--  without this; this makes them sync across your devices).
-- ============================================================

create table if not exists player_avatars (
  owner uuid not null references auth.users on delete cascade,
  name  text not null,                 -- lowercased player name
  image text not null,                 -- small base64 JPEG data URI
  updated_at timestamptz default now(),
  primary key (owner, name)
);

alter table player_avatars enable row level security;

drop policy if exists pa_owner on player_avatars;
create policy pa_owner on player_avatars for all
  using (owner = auth.uid()) with check (owner = auth.uid());
