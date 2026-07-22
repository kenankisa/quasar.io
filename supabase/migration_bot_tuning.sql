-- =============================================================================
-- Quasar.io — Bot av agresyonu (hunt_priority) uzaktan ayar
-- SQL Editor'da çalıştırın.
-- Authenticated okuyabilir; yalnızca admin (_is_admin_user) yazabilir.
-- =============================================================================

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

create or replace function public._is_admin_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_user_id is not null
    and (
      exists (select 1 from public.admin_users a where a.user_id = p_user_id)
      or exists (
        select 1 from auth.users u
        where u.id = p_user_id
          and coalesce(u.raw_app_meta_data->>'role', '') = 'admin'
      )
    );
$$;

create table if not exists public.bot_tuning (
  room_type text primary key
    check (room_type in ('simple', 'normal', 'elite', 'unique')),
  hunt_priority double precision not null
    check (hunt_priority >= 0 and hunt_priority <= 1),
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.bot_tuning (room_type, hunt_priority) values
  ('simple', 0.25),
  ('normal', 0.42),
  ('elite', 0.62),
  ('unique', 0.74)
on conflict (room_type) do nothing;

alter table public.bot_tuning enable row level security;

drop policy if exists "bot_tuning_select_authenticated" on public.bot_tuning;
create policy "bot_tuning_select_authenticated"
  on public.bot_tuning
  for select
  to authenticated
  using (true);

drop policy if exists "bot_tuning_select_anon" on public.bot_tuning;

drop policy if exists "bot_tuning_upsert_admin" on public.bot_tuning;
create policy "bot_tuning_upsert_admin"
  on public.bot_tuning
  for all
  to authenticated
  using (public._is_admin_user(auth.uid()))
  with check (public._is_admin_user(auth.uid()));

revoke select on public.bot_tuning from anon;
grant select on public.bot_tuning to authenticated;
grant insert, update, delete on public.bot_tuning to authenticated;
