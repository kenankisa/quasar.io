-- =============================================================================
-- Quasar.io — Tek cihaz / aktif oyun oturumu
-- SQL Editor'da çalıştırın (schema.sql ve oda migration'larından sonra).
-- =============================================================================

create table if not exists public.player_active_sessions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  device_id text not null,
  room_type text,
  started_at timestamptz not null default timezone('utc', now()),
  last_heartbeat_at timestamptz not null default timezone('utc', now())
);

create index if not exists player_active_sessions_heartbeat_idx
  on public.player_active_sessions (last_heartbeat_at);

alter table public.player_active_sessions enable row level security;

drop policy if exists "Kullanıcı kendi oturumunu görebilir" on public.player_active_sessions;
create policy "Kullanıcı kendi oturumunu görebilir"
  on public.player_active_sessions for select
  using (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Yardımcı: bayat oturumları temizle (90 sn heartbeat yoksa)
-- -----------------------------------------------------------------------------

create or replace function public._purge_stale_player_sessions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.player_active_sessions
  where last_heartbeat_at < timezone('utc', now()) - interval '90 seconds';
end;
$$;

-- -----------------------------------------------------------------------------
-- RPC — Oturum kontrolü
-- -----------------------------------------------------------------------------

create or replace function public.check_player_session(p_device_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_session public.player_active_sessions%rowtype;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  perform public._purge_stale_player_sessions();

  select *
  into v_session
  from public.player_active_sessions
  where user_id = v_user_id;

  if not found then
    return json_build_object(
      'active', false,
      'own_device', false,
      'room_type', null
    );
  end if;

  return json_build_object(
    'active', true,
    'own_device', v_session.device_id = nullif(trim(p_device_id), ''),
    'room_type', v_session.room_type
  );
end;
$$;

grant execute on function public.check_player_session(text) to authenticated;

-- -----------------------------------------------------------------------------
-- RPC — Oyuna girişte oturum al
-- -----------------------------------------------------------------------------

create or replace function public.claim_player_session(
  p_device_id text,
  p_room_type text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_device_id text := nullif(trim(p_device_id), '');
  v_room_type text := nullif(lower(trim(p_room_type)), '');
  v_session public.player_active_sessions%rowtype;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_device_id is null then
    raise exception 'invalid device_id';
  end if;

  perform public._purge_stale_player_sessions();

  select *
  into v_session
  from public.player_active_sessions
  where user_id = v_user_id
  for update;

  if found then
    if v_session.device_id <> v_device_id then
      raise exception 'player_already_active';
    end if;

    update public.player_active_sessions
    set
      room_type = coalesce(v_room_type, room_type),
      last_heartbeat_at = timezone('utc', now())
    where user_id = v_user_id;
    return;
  end if;

  insert into public.player_active_sessions (
    user_id,
    device_id,
    room_type,
    started_at,
    last_heartbeat_at
  )
  values (
    v_user_id,
    v_device_id,
    v_room_type,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

grant execute on function public.claim_player_session(text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- RPC — Heartbeat
-- -----------------------------------------------------------------------------

create or replace function public.heartbeat_player_session(p_device_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_device_id text := nullif(trim(p_device_id), '');
  v_updated int;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_device_id is null then
    raise exception 'invalid device_id';
  end if;

  update public.player_active_sessions
  set last_heartbeat_at = timezone('utc', now())
  where user_id = v_user_id
    and device_id = v_device_id;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'session_not_found';
  end if;
end;
$$;

grant execute on function public.heartbeat_player_session(text) to authenticated;

-- -----------------------------------------------------------------------------
-- RPC — Oturumu bırak
-- -----------------------------------------------------------------------------

create or replace function public.release_player_session(p_device_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_device_id text := nullif(trim(p_device_id), '');
begin
  if v_user_id is null then
    return;
  end if;

  if v_device_id is null then
    return;
  end if;

  delete from public.player_active_sessions
  where user_id = v_user_id
    and device_id = v_device_id;
end;
$$;

grant execute on function public.release_player_session(text) to authenticated;
