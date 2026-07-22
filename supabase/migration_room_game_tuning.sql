-- =============================================================================
-- Quasar.io — Evren oyun dengesi (JSON config per room)
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

create table if not exists public.room_game_tuning (
  room_type text primary key
    check (room_type in ('simple', 'normal', 'elite', 'unique')),
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.room_game_tuning (room_type, config) values
  ('simple', '{"v":1}'::jsonb),
  ('normal', '{"v":1}'::jsonb),
  ('elite', '{"v":1}'::jsonb),
  ('unique', '{"v":1}'::jsonb)
on conflict (room_type) do nothing;

-- Eski bot_tuning.hunt_priority değerlerini yeni tabloya taşı (varsa).
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'bot_tuning'
  ) then
    update public.room_game_tuning r
    set config = jsonb_set(
      coalesce(r.config, '{}'::jsonb),
      '{huntPriority}',
      to_jsonb(b.hunt_priority),
      true
    ),
    updated_at = timezone('utc', now())
    from public.bot_tuning b
    where r.room_type = b.room_type;
  end if;
end $$;

alter table public.room_game_tuning enable row level security;

drop policy if exists "room_game_tuning_select_authenticated" on public.room_game_tuning;
create policy "room_game_tuning_select_authenticated"
  on public.room_game_tuning
  for select
  to authenticated
  using (true);

drop policy if exists "room_game_tuning_select_anon" on public.room_game_tuning;

drop policy if exists "room_game_tuning_upsert_admin" on public.room_game_tuning;
create policy "room_game_tuning_upsert_admin"
  on public.room_game_tuning
  for all
  to authenticated
  using (public._is_admin_user(auth.uid()))
  with check (public._is_admin_user(auth.uid()));

revoke select on public.room_game_tuning from anon;
grant select on public.room_game_tuning to authenticated;
grant insert, update, delete on public.room_game_tuning to authenticated;
