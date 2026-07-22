-- =============================================================================
-- Quasar.io — Yük testi v2 (auth.users YOK)
-- Sahte oyuncular: load_test_ghosts + oturum/oda sayaçları.
-- SQL Editor'da çalıştırın (önceki load_test migration'larından sonra).
-- =============================================================================

-- Eski auth tabanlı test artık kullanılmıyor; tablo kalabilir ama boşaltılır.
create table if not exists public.load_test_ghosts (
  id uuid primary key default gen_random_uuid(),
  device_id text not null unique,
  room_type text not null,
  room_instance_id uuid not null
    references public.game_room_instances (id) on delete cascade,
  last_heartbeat_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  constraint load_test_ghosts_room_type_check
    check (room_type in ('normal', 'elite', 'unique'))
);

create index if not exists load_test_ghosts_room_idx
  on public.load_test_ghosts (room_type, room_instance_id);

alter table public.load_test_ghosts enable row level security;
revoke all on public.load_test_ghosts from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Oda doluluk = gerçek üyeler + ghost'lar
-- -----------------------------------------------------------------------------

create or replace function public._room_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select (
    select count(*)::int
    from public.game_room_members grm
    where grm.room_instance_id = p_room_id
      and grm.left_at is null
  ) + (
    select count(*)::int
    from public.load_test_ghosts g
    where g.room_instance_id = p_room_id
  );
$$;

revoke all on function public._room_occupancy(uuid) from public, anon, authenticated;

create or replace function public._sync_room_occupancy(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  v_count := public._room_occupancy(p_room_id);
  update public.game_room_instances
  set
    real_player_count = least(10, greatest(0, v_count)),
    updated_at = timezone('utc', now())
  where id = p_room_id;
  return v_count;
end;
$$;

revoke all on function public._sync_room_occupancy(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Ghost'u odaya yerleştir
-- -----------------------------------------------------------------------------

create or replace function public._load_test_place_ghost(
  p_ghost_id uuid,
  p_room_type text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_type text := lower(trim(p_room_type));
  v_room public.game_room_instances%rowtype;
  v_next_instance int;
  v_stale_before timestamptz := timezone('utc', now()) - interval '3 minutes';
  v_occ int;
begin
  if v_room_type not in ('normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

  -- Bayat odaları kapat (içinde ghost yoksa / bayatsa)
  update public.game_room_instances gri
  set
    status = 'closed',
    real_player_count = 0,
    leader_radius = 25,
    peak_leader_radius = 25,
    leader_radius_synced_at = null,
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before
    and public._room_occupancy(gri.id) = 0;

  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.leader_radius < 250
    and public._room_occupancy(gri.id) < 10
    and coalesce(gri.updated_at, gri.created_at) >= v_stale_before
  order by gri.instance_number asc
  limit 1
  for update;

  if not found then
    select *
    into v_room
    from public.game_room_instances
    where room_type = v_room_type
      and status = 'closed'
    order by instance_number asc
    limit 1
    for update;

    if found then
      delete from public.game_room_members where room_instance_id = v_room.id;
      delete from public.load_test_ghosts where room_instance_id = v_room.id;

      update public.game_room_instances
      set
        status = 'open',
        leader_radius = 25,
        peak_leader_radius = 25,
        leader_radius_synced_at = null,
        real_player_count = 0,
        updated_at = timezone('utc', now())
      where id = v_room.id
      returning * into v_room;
    else
      select coalesce(max(instance_number), 0) + 1
      into v_next_instance
      from public.game_room_instances
      where room_type = v_room_type;

      insert into public.game_room_instances (
        room_type,
        instance_number,
        real_player_count,
        leader_radius,
        peak_leader_radius,
        status
      )
      values (v_room_type, v_next_instance, 0, 25, 25, 'open')
      returning * into v_room;
    end if;
  end if;

  update public.load_test_ghosts
  set
    room_type = v_room_type,
    room_instance_id = v_room.id,
    last_heartbeat_at = timezone('utc', now())
  where id = p_ghost_id;

  v_occ := public._sync_room_occupancy(v_room.id);
  if v_occ > 20 then
    raise exception 'room_overfilled';
  end if;

  return v_room.id;
end;
$$;

revoke all on function public._load_test_place_ghost(uuid, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- join_game_room — ghost doluluğunu hesaba kat
-- -----------------------------------------------------------------------------

create or replace function public.join_game_room(p_room_type text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room_type text := lower(trim(p_room_type));
  v_room public.game_room_instances%rowtype;
  v_next_instance int;
  v_stale_before timestamptz := timezone('utc', now()) - interval '3 minutes';
  v_diamonds int;
  v_games_won int;
  v_required int;
  v_occ int;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_room_type = 'simple' then
    raise exception 'training_room_no_matchmaking';
  end if;

  if v_room_type not in ('normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if not public._is_admin_user(v_user_id) then
    select diamonds, games_won
    into v_diamonds, v_games_won
    from public.profiles
    where id = v_user_id;

    if coalesce(v_games_won, 0) = 0 then
      raise exception 'first_login_lock';
    end if;

    v_required := case v_room_type
      when 'normal' then 25
      when 'elite' then 100
      when 'unique' then 200
      else 0
    end;

    if coalesce(v_diamonds, 0) < v_required then
      raise exception 'insufficient_diamonds';
    end if;
  end if;

  perform public.leave_game_room(null);

  perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

  update public.game_room_members grm
  set left_at = timezone('utc', now())
  from public.game_room_instances gri
  where grm.room_instance_id = gri.id
    and gri.room_type = v_room_type
    and grm.left_at is null
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before;

  -- Bayat ghost'ları düşür
  delete from public.load_test_ghosts g
  using public.game_room_instances gri
  where g.room_instance_id = gri.id
    and gri.room_type = v_room_type
    and g.last_heartbeat_at < v_stale_before;

  update public.game_room_instances gri
  set
    status = 'closed',
    real_player_count = 0,
    leader_radius = 25,
    peak_leader_radius = 25,
    leader_radius_synced_at = null,
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and (
      public._room_occupancy(gri.id) = 0
      or coalesce(gri.updated_at, gri.created_at) < v_stale_before
    );

  -- Açık odaların sayacını senkronla
  update public.game_room_instances gri
  set
    real_player_count = least(10, public._room_occupancy(gri.id)),
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open';

  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.leader_radius < 250
    and public._room_occupancy(gri.id) < 10
    and coalesce(gri.updated_at, gri.created_at) >= v_stale_before
    and public._room_occupancy(gri.id) > 0
  order by gri.instance_number asc
  limit 1
  for update;

  if not found then
    select *
    into v_room
    from public.game_room_instances
    where room_type = v_room_type
      and status = 'closed'
    order by instance_number asc
    limit 1
    for update;

    if found then
      delete from public.game_room_members
      where room_instance_id = v_room.id;
      delete from public.load_test_ghosts
      where room_instance_id = v_room.id;

      update public.game_room_instances
      set
        status = 'open',
        leader_radius = 25,
        peak_leader_radius = 25,
        leader_radius_synced_at = null,
        real_player_count = 0,
        updated_at = timezone('utc', now())
      where id = v_room.id
      returning * into v_room;
    else
      select coalesce(max(instance_number), 0) + 1
      into v_next_instance
      from public.game_room_instances
      where room_type = v_room_type;

      insert into public.game_room_instances (
        room_type,
        instance_number,
        real_player_count,
        leader_radius,
        peak_leader_radius,
        status
      )
      values (v_room_type, v_next_instance, 0, 25, 25, 'open')
      returning * into v_room;
    end if;
  end if;

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, v_user_id);

  v_occ := public._sync_room_occupancy(v_room.id);

  select * into v_room from public.game_room_instances where id = v_room.id;

  return json_build_object(
    'room_instance_id', v_room.id,
    'instance_number', v_room.instance_number,
    'real_player_count', coalesce(v_occ, v_room.real_player_count),
    'leader_radius', v_room.leader_radius
  );
end;
$$;

revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;

-- leave sonrası occupancy senkron
create or replace function public.leave_game_room(p_room_instance_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_member record;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  for v_member in
    select id, room_instance_id
    from public.game_room_members
    where user_id = v_user_id
      and left_at is null
      and (p_room_instance_id is null or room_instance_id = p_room_instance_id)
    for update
  loop
    update public.game_room_members
    set left_at = timezone('utc', now())
    where id = v_member.id;

    perform public._sync_room_occupancy(v_member.room_instance_id);
  end loop;
end;
$$;

revoke all on function public.leave_game_room(uuid) from public, anon;
grant execute on function public.leave_game_room(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Aktif oturum sayısına ghost'ları ekle
-- -----------------------------------------------------------------------------

create or replace function public.get_admin_active_session_count()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_ghosts int;
begin
  perform public._require_admin();
  perform public._purge_stale_player_sessions();

  select count(*)::int
  into v_count
  from public.player_active_sessions s
  where not public._is_admin_user(s.user_id);

  select count(*)::int into v_ghosts from public.load_test_ghosts;

  return coalesce(v_count, 0) + coalesce(v_ghosts, 0);
end;
$$;

revoke all on function public.get_admin_active_session_count() from public, anon;
grant execute on function public.get_admin_active_session_count() to authenticated;

-- -----------------------------------------------------------------------------
-- Durum / heartbeat / stop / start (ghost)
-- -----------------------------------------------------------------------------

create or replace function public.admin_load_test_status()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active int;
  v_by_room json;
begin
  perform public._require_admin();

  select count(*)::int into v_active from public.load_test_ghosts;

  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_by_room
  from (
    select
      room_type,
      count(*)::int as players,
      count(distinct room_instance_id)::int as rooms
    from public.load_test_ghosts
    group by room_type
    order by room_type
  ) t;

  return json_build_object(
    'active_players', coalesce(v_active, 0),
    'by_room', v_by_room,
    'max_players', 100,
    'mode', 'ghost'
  );
end;
$$;

revoke all on function public.admin_load_test_status() from public, anon;
grant execute on function public.admin_load_test_status() to authenticated;

create or replace function public.admin_heartbeat_load_test()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ghosts int;
  v_rooms int;
begin
  perform public._require_admin();

  update public.load_test_ghosts
  set last_heartbeat_at = timezone('utc', now());
  get diagnostics v_ghosts = row_count;

  update public.game_room_instances gri
  set updated_at = timezone('utc', now())
  where gri.id in (
    select distinct room_instance_id from public.load_test_ghosts
  )
  and gri.status = 'open';
  get diagnostics v_rooms = row_count;

  return json_build_object(
    'sessions_touched', coalesce(v_ghosts, 0),
    'rooms_touched', coalesce(v_rooms, 0),
    'active_players', (select count(*)::int from public.load_test_ghosts)
  );
end;
$$;

revoke all on function public.admin_heartbeat_load_test() from public, anon;
grant execute on function public.admin_heartbeat_load_test() to authenticated;

create or replace function public.admin_stop_load_test()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_room_ids uuid[];
  v_count int;
  v_rid uuid;
  v_auth_ids uuid[];
begin
  perform public._require_admin();

  select coalesce(array_agg(distinct room_instance_id), '{}'::uuid[])
  into v_room_ids
  from public.load_test_ghosts;

  select count(*)::int into v_count from public.load_test_ghosts;

  -- Supabase: DELETE için WHERE zorunlu
  delete from public.load_test_ghosts where true;

  foreach v_rid in array v_room_ids
  loop
    perform public._sync_room_occupancy(v_rid);
  end loop;

  -- Eski auth tabanlı test kalıntıları (başarısız olsa ghost stop devam eder)
  begin
    if to_regclass('public.load_test_players') is not null then
      select coalesce(array_agg(user_id), '{}'::uuid[])
      into v_auth_ids
      from public.load_test_players;

      if coalesce(cardinality(v_auth_ids), 0) > 0 then
        update public.game_room_members
        set left_at = timezone('utc', now())
        where user_id = any (v_auth_ids) and left_at is null;

        delete from public.player_active_sessions where user_id = any (v_auth_ids);
        delete from public.load_test_players where user_id = any (v_auth_ids);
        begin
          delete from auth.identities where user_id = any (v_auth_ids);
          delete from auth.users where id = any (v_auth_ids);
        exception when others then
          null;
        end;
        v_count := v_count + coalesce(cardinality(v_auth_ids), 0);
      end if;
    end if;
  exception when others then
    null;
  end;

  return json_build_object('stopped', coalesce(v_count, 0));
end;
$$;

revoke all on function public.admin_stop_load_test() from public, anon;
grant execute on function public.admin_stop_load_test() to authenticated;

create or replace function public.admin_start_load_test(
  p_count int,
  p_room_type text default 'normal'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := greatest(1, least(coalesce(p_count, 0), 100));
  v_room_type text := lower(trim(coalesce(p_room_type, 'normal')));
  v_i int;
  v_ghost_id uuid;
  v_device_id text;
  v_room_id uuid;
  v_created int := 0;
  v_rooms int;
  v_next_instance int;
begin
  perform public._require_admin();

  if v_room_type not in ('normal', 'elite', 'unique') then
    return json_build_object('error', 'invalid_room_type', 'started', 0);
  end if;

  perform public.admin_stop_load_test();

  for v_i in 1..v_count
  loop
    perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

    v_ghost_id := gen_random_uuid();
    v_device_id := format('loadtest_%s', replace(v_ghost_id::text, '-', ''));
    v_room_id := null;

    select gri.id
    into v_room_id
    from public.game_room_instances gri
    where gri.room_type = v_room_type
      and gri.status = 'open'
      and gri.leader_radius < 250
      and public._room_occupancy(gri.id) < 10
    order by gri.instance_number asc
    limit 1
    for update;

    if v_room_id is null then
      select gri.id
      into v_room_id
      from public.game_room_instances gri
      where gri.room_type = v_room_type
        and gri.status = 'closed'
      order by gri.instance_number asc
      limit 1
      for update;

      if v_room_id is not null then
        delete from public.game_room_members where room_instance_id = v_room_id;
        delete from public.load_test_ghosts where room_instance_id = v_room_id;
        update public.game_room_instances
        set
          status = 'open',
          leader_radius = 25,
          peak_leader_radius = 25,
          leader_radius_synced_at = null,
          real_player_count = 0,
          updated_at = timezone('utc', now())
        where id = v_room_id;
      else
        select coalesce(max(instance_number), 0) + 1
        into v_next_instance
        from public.game_room_instances
        where room_type = v_room_type;

        insert into public.game_room_instances (
          room_type,
          instance_number,
          real_player_count,
          leader_radius,
          peak_leader_radius,
          status
        ) values (
          v_room_type,
          v_next_instance,
          0,
          25,
          25,
          'open'
        )
        returning id into v_room_id;
      end if;
    end if;

    insert into public.load_test_ghosts (
      id,
      device_id,
      room_type,
      room_instance_id
    ) values (
      v_ghost_id,
      v_device_id,
      v_room_type,
      v_room_id
    );

    perform public._sync_room_occupancy(v_room_id);
    v_created := v_created + 1;
  end loop;

  select count(distinct room_instance_id)::int
  into v_rooms
  from public.load_test_ghosts;

  return json_build_object(
    'started', v_created,
    'room_type', v_room_type,
    'rooms_used', coalesce(v_rooms, 0),
    'active_players', (select count(*)::int from public.load_test_ghosts),
    'mode', 'ghost'
  );
exception when others then
  begin
    delete from public.load_test_ghosts where true;
  exception when others then
    null;
  end;
  return json_build_object(
    'error', SQLERRM,
    'started', 0,
    'active_players', 0
  );
end;
$$;

revoke all on function public.admin_start_load_test(int, text) from public, anon;
grant execute on function public.admin_start_load_test(int, text) to authenticated;
