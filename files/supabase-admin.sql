-- ============================================================
--  Dig Pro — Admin panel + Feedback
--  Run once in Supabase → SQL Editor. Safe to re-run.
--
--  Security model: nothing here exposes other users' data to a normal
--  client. Admin reads go through SECURITY DEFINER functions that first
--  check is_admin(auth.uid()); everyone else is refused by the database.
-- ============================================================

-- who is an admin
create table if not exists admins (
  user_id uuid primary key references auth.users on delete cascade,
  added_at timestamptz default now()
);
alter table admins enable row level security;
drop policy if exists admins_self_read on admins;
create policy admins_self_read on admins for select using (user_id = auth.uid());

create or replace function is_admin(uid uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (select 1 from admins where user_id = uid);
$$;

-- feedback: bugs, suggestions, other
create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete set null,
  email text,
  kind text not null default 'bug',        -- 'bug' | 'suggestion' | 'other'
  message text not null,
  status text not null default 'open',      -- 'open' | 'resolved'
  app_version text,
  created_at timestamptz default now()
);
alter table feedback enable row level security;

-- anyone (guest or signed-in) may submit; signed-in rows carry their id
drop policy if exists fb_insert on feedback;
create policy fb_insert on feedback for insert
  with check (user_id is null or user_id = auth.uid());

-- you can read your own; admins read all
drop policy if exists fb_read on feedback;
create policy fb_read on feedback for select
  using (user_id = auth.uid() or is_admin(auth.uid()));

-- only admins change status
drop policy if exists fb_update on feedback;
create policy fb_update on feedback for update
  using (is_admin(auth.uid())) with check (is_admin(auth.uid()));

-- ---------- admin-only read functions ----------
create or replace function admin_stats()
returns json language plpgsql security definer
set search_path = public as $$
declare result json;
begin
  if not is_admin(auth.uid()) then raise exception 'not authorized'; end if;
  select json_build_object(
    'users',          (select count(*) from profiles),
    'signups_7d',     (select count(*) from profiles where created_at > now() - interval '7 days'),
    'games',          (select count(*) from games),
    'games_7d',       (select count(*) from games where played_at > now() - interval '7 days'),
    'leagues',        (select count(*) from leagues),
    'live_now',       (select count(*) from live_games where active),
    'feedback_open',  (select count(*) from feedback where status = 'open'),
    'feedback_total', (select count(*) from feedback)
  ) into result;
  return result;
end; $$;

create or replace function admin_users()
returns table(id uuid, email text, created_at timestamptz, games bigint)
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin(auth.uid()) then raise exception 'not authorized'; end if;
  return query
    select p.id, p.email, p.created_at,
           (select count(*) from games g where g.owner = p.id)
    from profiles p
    order by p.created_at desc
    limit 500;
end; $$;

create or replace function admin_feedback()
returns setof feedback language plpgsql security definer
set search_path = public as $$
begin
  if not is_admin(auth.uid()) then raise exception 'not authorized'; end if;
  return query select * from feedback order by created_at desc limit 500;
end; $$;

-- ============================================================
--  Make yourself an admin (edit the email if different):
-- ============================================================
insert into admins (user_id)
select id from auth.users where lower(email) = lower('mr.shaneez@gmail.com')
on conflict do nothing;
