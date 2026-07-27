-- =============================================================================
-- Quasar.io — Hardcore: always accept joins (live + Arena Test)
-- Fixes: softcap ~450 syncs leader_radius ≥280 → legacy join block;
--         ghost members fill the 20-cap while few look "alive".
-- Also: purge must NOT call promote (recursion broke Arena Test +1).
-- Run after migration_hardcore_seat_release.sql
-- If you already ran an older copy of this file, also run:
--   migration_hardcore_purge_no_recurse.sql
-- =============================================================================

-- 1) Purge Hardcore members with no recent session heartbeat
create or replace function public._hardcore_purge_inactive_members(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stale timestamptz := timezone('utc', now()) - interval '45 seconds';
  v_purged int := 0;
  v_room public.game_room_instances%rowtype;
begin
  if p_room_id is null then
    return 0;
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_id
  for update;

  if not found then
    return 0;
  end if;
  if lower(coalesce(v_room.room_type, '')) <> 'hardcore' then
    return 0;
  end if;

  -- Arena Test: harness owns seats — skip heartbeat purge.
  if coalesce(v_room.is_load_test, false) then
    perform public._sync_room_occupancy(p_room_id);
    return 0;
  end if;

  update public.game_room_members grm
  set left_at = timezone('utc', now())
  where grm.room_instance_id = p_room_id
    and grm.left_at is null
    and not exists (
      select 1
      from public.player_active_sessions pas
      where pas.user_id = grm.user_id
        and pas.last_heartbeat_at >= v_stale
    );

  get diagnostics v_purged = row_count;

  if v_purged > 0 then
    begin
      delete from public.hardcore_queue hq
      where hq.user_id in (
        select grm.user_id
        from public.game_room_members grm
        where grm.room_instance_id = p_room_id
          and grm.left_at is not null
          and grm.left_at >= timezone('utc', now()) - interval '2 minutes'
      );
    exception when others then
      null;
    end;
    begin
      delete from public.hardcore_test_queue hq
      where hq.user_id in (
        select grm.user_id
        from public.game_room_members grm
        where grm.room_instance_id = p_room_id
          and grm.left_at is not null
          and grm.left_at >= timezone('utc', now()) - interval '2 minutes'
      );
    exception when undefined_table then
      null;
    end;
  end if;

  -- Sync only — never call promote from here.
  -- promote_* already calls purge at start; calling back causes stack overflow
  -- and rolls back join/reconcile transactions (Arena Test +1 fails).
  perform public._sync_room_occupancy(p_room_id);

  return coalesce(v_purged, 0);
end;
$$;

revoke all on function public._hardcore_purge_inactive_members(uuid)
  from public, anon, authenticated;

-- 2) Live promote — NEVER gate on leader_radius (always-open singleton)
create or replace function public._promote_hardcore_queue(p_room_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_cap int;
  v_occ int;
  v_next uuid;
  v_gen int;
  v_guard int := 0;
begin
  select * into v_room
  from public.game_room_instances
  where id = p_room_id
  for update;

  if not found then
    return null;
  end if;

  if lower(v_room.room_type) <> 'hardcore'
     or coalesce(v_room.is_load_test, false)
  then
    return null;
  end if;

  perform public._hardcore_purge_inactive_members(p_room_id);

  select * into v_room
  from public.game_room_instances
  where id = p_room_id
  for update;

  if v_room.status <> 'open' then
    update public.game_room_instances
    set
      status = 'open',
      leader_radius = 25,
      peak_leader_radius = 25,
      leader_radius_synced_at = null,
      real_player_count = 0,
      match_generation = coalesce(match_generation, 0) + 1,
      updated_at = timezone('utc', now())
    where id = p_room_id
    returning * into v_room;
  end if;

  v_cap := public._hardcore_max_players();
  if v_cap <= 0 then
    return null;
  end if;

  loop
    v_guard := v_guard + 1;
    if v_guard > 25 then
      return null;
    end if;

    begin
      v_occ := public._room_hardcore_seat_occupancy(p_room_id);
    exception when undefined_function then
      begin
        v_occ := public._room_human_occupancy(p_room_id);
      exception when undefined_function then
        v_occ := public._room_occupancy(p_room_id);
      end;
    end;

    if coalesce(v_occ, 0) >= v_cap then
      return null;
    end if;

    select user_id into v_next
    from public.hardcore_queue
    where admitted_room_id is null
    order by enqueued_at asc
    limit 1
    for update skip locked;

    if v_next is null then
      return null;
    end if;

    if exists (
      select 1 from public.game_room_members
      where user_id = v_next and left_at is null
    ) then
      delete from public.hardcore_queue where user_id = v_next;
      continue;
    end if;

    if coalesce(public._is_admin_user(v_next), false) then
      delete from public.hardcore_queue where user_id = v_next;
      continue;
    end if;

    v_gen := coalesce(v_room.match_generation, 1);

    insert into public.game_room_members (room_instance_id, user_id)
    values (p_room_id, v_next);

    update public.hardcore_queue
    set
      admitted_room_id = p_room_id,
      admitted_at = timezone('utc', now()),
      match_generation = v_gen
    where user_id = v_next;

    perform public._sync_room_occupancy(p_room_id);
    return v_next;
  end loop;
end;
$$;

revoke all on function public._promote_hardcore_queue(uuid)
  from public, anon, authenticated;

-- 3) Live join — purge ghosts first; NO leader_radius gate
create or replace function public.join_hardcore_universe()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_cap int;
  v_occ int;
  v_pos int;
  v_cd timestamptz;
  v_trophies int;
  v_is_admin boolean := false;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  begin
    v_is_admin := public._is_admin_user(v_user_id);
  exception when undefined_function then
    v_is_admin := false;
  end;

  if not v_is_admin then
    if public._needs_first_login_lock(v_user_id) then
      raise exception 'first_login_lock';
    end if;

    select
      coalesce(trophy_wins_simple, 0)
        + coalesce(trophy_wins_normal, 0)
        + coalesce(trophy_wins_elite, 0)
        + coalesce(trophy_wins_unique, 0),
      hardcore_cooldown_until
    into v_trophies, v_cd
    from public.profiles
    where id = v_user_id;

    if coalesce(v_trophies, 0) < 10 then
      raise exception 'hardcore_trophy_lock';
    end if;

    if v_cd is not null and v_cd > timezone('utc', now()) then
      raise exception 'hardcore_cooldown'
        using detail = to_char(v_cd at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    end if;
  end if;

  perform public.leave_game_room(null);
  delete from public.hardcore_queue
  where user_id = v_user_id
    and admitted_room_id is null;

  perform pg_advisory_xact_lock(hashtext('join_game_room_hardcore'));

  begin
    perform public._purge_stale_room_occupancy('hardcore');
  exception when undefined_function then
    null;
  end;

  v_room := public._ensure_hardcore_singleton();
  perform public._hardcore_purge_inactive_members(v_room.id);

  update public.game_room_instances
  set
    status = 'open',
    updated_at = timezone('utc', now())
  where id = v_room.id
    and status is distinct from 'open';

  select * into v_room from public.game_room_instances where id = v_room.id;

  v_cap := public._hardcore_max_players();

  begin
    v_occ := public._room_hardcore_seat_occupancy(v_room.id);
  exception when undefined_function then
    begin
      v_occ := public._room_human_occupancy(v_room.id);
    exception when undefined_function then
      v_occ := public._room_occupancy(v_room.id);
    end;
  end;

  if v_is_admin then
    insert into public.game_room_members (room_instance_id, user_id)
    values (v_room.id, v_user_id);
    v_occ := public._sync_room_occupancy(v_room.id);
    select * into v_room from public.game_room_instances where id = v_room.id;
    delete from public.hardcore_queue where user_id = v_user_id;

    return json_build_object(
      'queued', false,
      'room_instance_id', v_room.id,
      'id', v_room.id,
      'instance_number', 1,
      'real_player_count', coalesce(v_occ, v_room.real_player_count),
      'leader_radius', v_room.leader_radius,
      'room_type', 'hardcore',
      'match_generation', coalesce(v_room.match_generation, 1),
      'admin_spectator_seat', true
    );
  end if;

  -- Seat only — leader size (450 softcap / 600 win) never blocks joins.
  if v_cap > 0 and coalesce(v_occ, 0) < v_cap then
    insert into public.game_room_members (room_instance_id, user_id)
    values (v_room.id, v_user_id);
    v_occ := public._sync_room_occupancy(v_room.id);
    select * into v_room from public.game_room_instances where id = v_room.id;
    delete from public.hardcore_queue where user_id = v_user_id;

    return json_build_object(
      'queued', false,
      'room_instance_id', v_room.id,
      'id', v_room.id,
      'instance_number', 1,
      'real_player_count', coalesce(v_occ, v_room.real_player_count),
      'leader_radius', v_room.leader_radius,
      'room_type', 'hardcore',
      'match_generation', coalesce(v_room.match_generation, 1)
    );
  end if;

  insert into public.hardcore_queue (user_id, enqueued_at)
  values (v_user_id, timezone('utc', now()))
  on conflict (user_id) do update
    set
      enqueued_at = excluded.enqueued_at,
      admitted_room_id = null,
      admitted_at = null,
      match_generation = null;

  v_pos := public._hardcore_queue_position(v_user_id);

  return json_build_object(
    'queued', true,
    'position', v_pos,
    'room_type', 'hardcore'
  );
end;
$$;

revoke all on function public.join_hardcore_universe() from public, anon;
grant execute on function public.join_hardcore_universe() to authenticated;

-- 4) Arena Test join — purge then seat (no leader gate)
create or replace function public.join_hardcore_test_universe()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_cap int;
  v_occ int;
  v_pos int;
  v_is_admin boolean := false;
  v_is_sim boolean := false;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  begin
    v_is_admin := public._is_admin_user(v_user_id);
  exception when undefined_function then
    v_is_admin := false;
  end;

  begin
    v_is_sim := public._is_sim_auth_user(v_user_id);
  exception when undefined_function then
    v_is_sim := false;
  end;

  if not v_is_admin and not v_is_sim then
    raise exception 'hardcore_test_forbidden';
  end if;

  perform public.leave_game_room(null);
  delete from public.hardcore_test_queue
  where user_id = v_user_id
    and admitted_room_id is null;

  perform pg_advisory_xact_lock(hashtext('join_hardcore_test_universe'));

  v_room := public._ensure_hardcore_load_test_singleton();
  perform public._hardcore_purge_inactive_members(v_room.id);

  -- Purge must not leave the singleton closed/split; reopen before seating.
  update public.game_room_instances
  set
    status = 'open',
    updated_at = timezone('utc', now())
  where id = v_room.id
    and status is distinct from 'open';

  select * into v_room from public.game_room_instances where id = v_room.id;

  begin
    v_cap := greatest(0, public._hardcore_max_players());
  exception when others then
    v_cap := 20;
  end;

  v_occ := public._room_hardcore_test_seat_occupancy(v_room.id);

  if v_is_admin then
    insert into public.game_room_members (room_instance_id, user_id)
    values (v_room.id, v_user_id);
    perform public._sync_room_occupancy(v_room.id);
    select * into v_room from public.game_room_instances where id = v_room.id;
    delete from public.hardcore_test_queue where user_id = v_user_id;

    return json_build_object(
      'queued', false,
      'room_instance_id', v_room.id,
      'id', v_room.id,
      'instance_number', coalesce(v_room.instance_number, 1),
      'real_player_count', coalesce(v_room.real_player_count, v_occ),
      'leader_radius', coalesce(v_room.leader_radius, 25),
      'room_type', 'hardcore',
      'status', v_room.status,
      'is_load_test', true,
      'match_generation', coalesce(v_room.match_generation, 1),
      'admin_spectator_seat', true
    );
  end if;

  if v_cap > 0 and coalesce(v_occ, 0) < v_cap then
    insert into public.game_room_members (room_instance_id, user_id)
    values (v_room.id, v_user_id);
    v_occ := public._sync_room_occupancy(v_room.id);
    select * into v_room from public.game_room_instances where id = v_room.id;
    delete from public.hardcore_test_queue where user_id = v_user_id;

    return json_build_object(
      'queued', false,
      'room_instance_id', v_room.id,
      'id', v_room.id,
      'instance_number', coalesce(v_room.instance_number, 1),
      'real_player_count', coalesce(v_occ, v_room.real_player_count),
      'leader_radius', coalesce(v_room.leader_radius, 25),
      'room_type', 'hardcore',
      'status', v_room.status,
      'is_load_test', true,
      'match_generation', coalesce(v_room.match_generation, 1)
    );
  end if;

  insert into public.hardcore_test_queue (user_id, enqueued_at)
  values (v_user_id, timezone('utc', now()))
  on conflict (user_id) do update
    set
      enqueued_at = excluded.enqueued_at,
      admitted_room_id = null,
      admitted_at = null,
      match_generation = null;

  v_pos := public._hardcore_test_queue_position(v_user_id);

  return json_build_object(
    'queued', true,
    'position', v_pos,
    'room_type', 'hardcore',
    'is_load_test', true
  );
end;
$$;

revoke all on function public.join_hardcore_test_universe() from public, anon;
grant execute on function public.join_hardcore_test_universe() to authenticated;

-- 4b) Arena Test promote — purge inactive before seating queued sims
create or replace function public._promote_hardcore_test_queue(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_cap int;
  v_occ int;
  v_next uuid;
  v_gen int;
  v_guard int := 0;
begin
  select * into v_room
  from public.game_room_instances
  where id = p_room_id
  for update;

  if not found then
    return;
  end if;
  if lower(v_room.room_type) <> 'hardcore'
     or not coalesce(v_room.is_load_test, false)
  then
    return;
  end if;

  perform public._hardcore_purge_inactive_members(p_room_id);

  select * into v_room
  from public.game_room_instances
  where id = p_room_id
  for update;

  if v_room.status <> 'open' then
    update public.game_room_instances
    set
      status = 'open',
      leader_radius = 25,
      peak_leader_radius = 25,
      leader_radius_synced_at = null,
      real_player_count = 0,
      match_generation = coalesce(match_generation, 0) + 1,
      match_started_at = null,
      cosmic_seed = null,
      updated_at = timezone('utc', now())
    where id = p_room_id
    returning * into v_room;
  end if;

  begin
    v_cap := greatest(0, public._hardcore_max_players());
  exception when others then
    v_cap := 20;
  end;

  loop
    v_guard := v_guard + 1;
    if v_guard > 25 then
      exit;
    end if;

    v_occ := public._room_hardcore_test_seat_occupancy(p_room_id);
    if v_cap <= 0 or v_occ >= v_cap then
      exit;
    end if;

    select user_id into v_next
    from public.hardcore_test_queue
    where admitted_room_id is null
    order by enqueued_at asc
    limit 1
    for update skip locked;

    if v_next is null then
      exit;
    end if;

    if exists (
      select 1 from public.game_room_members
      where user_id = v_next and left_at is null
    ) then
      delete from public.hardcore_test_queue where user_id = v_next;
      continue;
    end if;

    if coalesce(public._is_admin_user(v_next), false) then
      delete from public.hardcore_test_queue where user_id = v_next;
      continue;
    end if;

    insert into public.game_room_members (room_instance_id, user_id)
    values (p_room_id, v_next);

    v_gen := coalesce(v_room.match_generation, 1);
    update public.hardcore_test_queue
    set
      admitted_room_id = p_room_id,
      admitted_at = timezone('utc', now()),
      match_generation = v_gen
    where user_id = v_next;

    perform public._sync_room_occupancy(p_room_id);
  end loop;
end;
$$;

revoke all on function public._promote_hardcore_test_queue(uuid)
  from public, anon, authenticated;

-- 5) Admin live ghost purge (same idea as Arena Test reconcile)
create or replace function public.admin_hardcore_live_purge_inactive()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_purged int := 0;
  v_occ int := 0;
begin
  perform public._require_admin();
  v_room := public._ensure_hardcore_singleton();
  v_purged := public._hardcore_purge_inactive_members(v_room.id);
  begin
    perform public._promote_hardcore_queue(v_room.id);
  exception when others then
    null;
  end;
  begin
    v_occ := public._room_hardcore_seat_occupancy(v_room.id);
  exception when others then
    v_occ := coalesce(v_room.real_player_count, 0);
  end;
  return json_build_object(
    'purged', coalesce(v_purged, 0),
    'seat_occupancy', coalesce(v_occ, 0),
    'room_id', v_room.id
  );
end;
$$;

revoke all on function public.admin_hardcore_live_purge_inactive()
  from public, anon;
grant execute on function public.admin_hardcore_live_purge_inactive()
  to authenticated;

comment on function public._hardcore_purge_inactive_members(uuid) is
  'Hardcore live/test: drop members without recent session heartbeat; free seats. Does not promote (avoids purge↔promote recursion).';
comment on function public.join_hardcore_universe() is
  'Live Hardcore join — seat cap only; leader size never blocks.';
comment on function public.join_hardcore_test_universe() is
  'Arena Test join — purge inactive then seat; leader size never blocks.';

-- 6) Arena Test singleton: reopen existing row (do not spawn duplicates)
create or replace function public._ensure_hardcore_load_test_singleton()
returns public.game_room_instances
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_id uuid;
begin
  select id into v_id
  from public.game_room_instances gri
  where gri.room_type = 'hardcore'
    and coalesce(gri.is_load_test, false) = true
  order by
    case when gri.status = 'open' then 0 else 1 end,
    gri.instance_number asc,
    gri.created_at asc
  limit 1
  for update;

  if v_id is null then
    insert into public.game_room_instances (
      room_type,
      instance_number,
      real_player_count,
      leader_radius,
      status,
      is_load_test,
      match_generation
    )
    values ('hardcore', 1, 0, 25, 'open', true, 1)
    returning * into v_room;
    return v_room;
  end if;

  update public.game_room_instances
  set
    status = 'open',
    updated_at = timezone('utc', now())
  where id = v_id
  returning * into v_room;

  return v_room;
end;
$$;

revoke all on function public._ensure_hardcore_load_test_singleton()
  from public, anon, authenticated;
