-- =============================================================================
-- Quasar.io — High güvenlik düzeltmeleri
-- 1) _guard_profile_economy: peak_diamonds + skill_tree + rank_points
-- 2) Lobide sunucu kimlikli chat (broadcast spoof kapatma)
-- 3) Oda üyesi ID listesi (istemci broadcast allowlist)
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Profil ekonomi koruması — eksik alanları geri ekle
-- -----------------------------------------------------------------------------

create or replace function public._guard_profile_economy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('quasar.trusted_profile_write', true) = '1' then
    return NEW;
  end if;

  if NEW.diamonds is distinct from OLD.diamonds
     or NEW.games_won is distinct from OLD.games_won
     or NEW.rank_points is distinct from OLD.rank_points
     or NEW.active_skin is distinct from OLD.active_skin
     or NEW.peak_diamonds is distinct from OLD.peak_diamonds
     or NEW.skill_tree is distinct from OLD.skill_tree then
    raise exception 'forbidden_profile_field';
  end if;

  return NEW;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2) Aktif oda üyeleri — yalnızca oda üyesi sorabilir
-- -----------------------------------------------------------------------------

create or replace function public.get_room_active_member_ids(p_room_instance_id uuid)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_ids uuid[];
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_room_instance_id is null then
    raise exception 'room_required';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    raise exception 'not an active room member';
  end if;

  select coalesce(array_agg(grm.user_id order by grm.joined_at), '{}'::uuid[])
  into v_ids
  from public.game_room_members grm
  where grm.room_instance_id = p_room_instance_id
    and grm.left_at is null;

  return v_ids;
end;
$$;

revoke all on function public.get_room_active_member_ids(uuid) from public, anon;
grant execute on function public.get_room_active_member_ids(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Lobide sunucu kimlikli chat (ephemeral)
-- -----------------------------------------------------------------------------

create table if not exists public.lobby_chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  body text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists lobby_chat_messages_created_at_idx
  on public.lobby_chat_messages (created_at desc);

alter table public.lobby_chat_messages enable row level security;

revoke all on public.lobby_chat_messages from public, anon;
grant select on public.lobby_chat_messages to authenticated;

drop policy if exists "lobby_chat_select_authenticated" on public.lobby_chat_messages;
create policy "lobby_chat_select_authenticated"
  on public.lobby_chat_messages
  for select
  to authenticated
  using (true);

-- Doğrudan yazma yok — yalnızca security definer RPC.
revoke insert, update, delete on public.lobby_chat_messages
  from public, anon, authenticated;

alter table public.lobby_chat_messages replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.lobby_chat_messages;
exception
  when duplicate_object then null;
end;
$$;

create or replace function public.send_lobby_chat(p_body text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := left(trim(coalesce(p_body, '')), 120);
  v_name text;
  v_last_at timestamptz;
  v_row public.lobby_chat_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if length(v_body) < 1 then
    raise exception 'empty_body';
  end if;

  select max(m.created_at)
    into v_last_at
  from public.lobby_chat_messages m
  where m.user_id = v_uid;

  if v_last_at is not null
     and v_last_at > timezone('utc', now()) - interval '900 milliseconds' then
    raise exception 'chat_cooldown';
  end if;

  select left(
    coalesce(nullif(trim(p.username), ''), 'Traveler'),
    12
  )
  into v_name
  from public.profiles p
  where p.id = v_uid;

  v_name := coalesce(v_name, 'Traveler');

  insert into public.lobby_chat_messages (user_id, username, body)
  values (v_uid, v_name, v_body)
  returning * into v_row;

  -- Bayat satırları temizle.
  delete from public.lobby_chat_messages
  where created_at < timezone('utc', now()) - interval '2 minutes';

  return jsonb_build_object(
    'id', v_row.id,
    'user_id', v_row.user_id,
    'username', v_row.username,
    'body', v_row.body,
    'created_at', v_row.created_at
  );
end;
$$;

revoke all on function public.send_lobby_chat(text) from public, anon;
grant execute on function public.send_lobby_chat(text) to authenticated;

notify pgrst, 'reload schema';
