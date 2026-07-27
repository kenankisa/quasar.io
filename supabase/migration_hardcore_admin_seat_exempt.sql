-- =============================================================================
-- Quasar.io — Hardcore: admin does not consume a player seat (can be 21st)
-- Run once after migration_admin_reserved_hardcore.sql
-- =============================================================================

-- Seat count for Hardcore capacity: real players excluding admins (and sims).
create or replace function public._room_hardcore_seat_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public, auth
as $$
  select count(*)::int
  from public.game_room_members grm
  where grm.room_instance_id = p_room_id
    and grm.left_at is null
    and not public._is_sim_auth_user(grm.user_id)
    and not coalesce(public._is_admin_user(grm.user_id), false);
$$;

revoke all on function public._room_hardcore_seat_occupancy(uuid)
  from public, anon, authenticated;

-- Sync: Hardcore real_player_count ignores admins so lobby shows ≤20.
create or replace function public._sync_room_occupancy(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_humans int;
  v_room_type text;
  v_cap int;
begin
  select room_type into v_room_type
  from public.game_room_instances
  where id = p_room_id;

  if lower(coalesce(v_room_type, '')) = 'hardcore' then
    begin
      v_humans := public._room_hardcore_seat_occupancy(p_room_id);
    exception when undefined_function then
      begin
        v_humans := public._room_human_occupancy(p_room_id);
      exception when undefined_function then
        v_humans := public._room_occupancy(p_room_id);
      end;
    end;
  else
    begin
      v_humans := public._room_human_occupancy(p_room_id);
    exception when undefined_function then
      v_humans := public._room_occupancy(p_room_id);
    end;
  end if;

  v_cap := public._max_players_for_room_type(coalesce(v_room_type, 'normal'));

  update public.game_room_instances
  set
    real_player_count = least(v_cap, greatest(0, v_humans)),
    updated_at = timezone('utc', now())
  where id = p_room_id;

  return least(v_cap, greatest(0, v_humans));
end;
$$;

revoke all on function public._sync_room_occupancy(uuid)
  from public, anon, authenticated;

-- Promote queue uses seat occupancy (admin ignored).
create or replace function public._promote_hardcore_queue(p_room_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_cap int := 20;
  v_occ int;
  v_next uuid;
  v_gen int;
begin
  select * into v_room
  from public.game_room_instances
  where id = p_room_id
  for update;

  if not found then
    return null;
  end if;

  if lower(v_room.room_type) <> 'hardcore' or v_room.status <> 'open' then
    return null;
  end if;

  if coalesce(v_room.leader_radius, 25) >= 280 then
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
    return null;
  end if;

  -- Never promote another admin into a "seat" — admins join via join_hardcore.
  if coalesce(public._is_admin_user(v_next), false) then
    delete from public.hardcore_queue where user_id = v_next;
    return null;
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
end;
$$;

revoke all on function public._promote_hardcore_queue(uuid)
  from public, anon, authenticated;

-- join_hardcore: admin joins any open room even at 20 seats (does not consume seat).
create or replace function public.join_hardcore_universe()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_cap int := 20;
  v_occ int;
  v_next_instance int;
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

  -- Admin: any open hardcore room (full OK — admin is not a seat).
  if v_is_admin then
    begin
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = 'hardcore'
        and gri.status = 'open'
        and not public._room_has_load_test(gri.id)
      order by public._room_hardcore_seat_occupancy(gri.id) desc,
               gri.instance_number asc
      limit 1
      for update;
    exception when undefined_function then
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = 'hardcore'
        and gri.status = 'open'
      order by gri.instance_number asc
      limit 1
      for update;
    end;

    if found then
      insert into public.game_room_members (room_instance_id, user_id)
      values (v_room.id, v_user_id);

      v_occ := public._sync_room_occupancy(v_room.id);
      select * into v_room from public.game_room_instances where id = v_room.id;
      delete from public.hardcore_queue where user_id = v_user_id;

      return json_build_object(
        'queued', false,
        'room_instance_id', v_room.id,
        'instance_number', v_room.instance_number,
        'real_player_count', coalesce(v_occ, v_room.real_player_count),
        'leader_radius', v_room.leader_radius,
        'room_type', 'hardcore',
        'match_generation', coalesce(v_room.match_generation, 1),
        'admin_spectator_seat', true
      );
    end if;

    -- No open room — reopen/create then sit
  else
    -- Regular players: open room under seat cap + leader gate
    begin
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = 'hardcore'
        and gri.status = 'open'
        and gri.leader_radius < 280
        and not public._room_has_load_test(gri.id)
        and public._room_hardcore_seat_occupancy(gri.id) < v_cap
      order by public._room_hardcore_seat_occupancy(gri.id) desc,
               gri.instance_number asc
      limit 1
      for update;
    exception when undefined_function then
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = 'hardcore'
        and gri.status = 'open'
        and gri.leader_radius < 280
        and public._room_occupancy(gri.id) < v_cap
      order by public._room_occupancy(gri.id) desc, gri.instance_number asc
      limit 1
      for update;
    end;

    if found then
      begin
        v_occ := public._room_hardcore_seat_occupancy(v_room.id);
      exception when undefined_function then
        v_occ := public._room_occupancy(v_room.id);
      end;

      if coalesce(v_occ, 0) < v_cap then
        insert into public.game_room_members (room_instance_id, user_id)
        values (v_room.id, v_user_id);
        v_occ := public._sync_room_occupancy(v_room.id);
        select * into v_room from public.game_room_instances where id = v_room.id;
        delete from public.hardcore_queue where user_id = v_user_id;

        return json_build_object(
          'queued', false,
          'room_instance_id', v_room.id,
          'instance_number', v_room.instance_number,
          'real_player_count', coalesce(v_occ, v_room.real_player_count),
          'leader_radius', v_room.leader_radius,
          'room_type', 'hardcore',
          'match_generation', coalesce(v_room.match_generation, 1)
        );
      end if;
    end if;

    if exists (
      select 1
      from public.game_room_instances
      where room_type = 'hardcore'
        and status = 'open'
        and leader_radius < 280
    ) then
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
    end if;
  end if;

  -- Open / create room
  select *
  into v_room
  from public.game_room_instances
  where room_type = 'hardcore'
    and status = 'closed'
  order by instance_number asc
  limit 1
  for update;

  if found then
    delete from public.game_room_members where room_instance_id = v_room.id;
    begin
      delete from public.load_test_ghosts where room_instance_id = v_room.id;
    exception when undefined_table then
      null;
    end;

    update public.game_room_instances
    set
      status = 'open',
      leader_radius = 25,
      peak_leader_radius = 25,
      leader_radius_synced_at = null,
      real_player_count = 0,
      match_generation = coalesce(match_generation, 0) + 1,
      updated_at = timezone('utc', now())
    where id = v_room.id
    returning * into v_room;
  else
    select coalesce(max(instance_number), 0) + 1
    into v_next_instance
    from public.game_room_instances
    where room_type = 'hardcore';

    insert into public.game_room_instances (
      room_type,
      instance_number,
      real_player_count,
      leader_radius,
      peak_leader_radius,
      match_generation,
      status
    )
    values ('hardcore', v_next_instance, 0, 25, 25, 1, 'open')
    returning * into v_room;
  end if;

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, v_user_id);
  v_occ := public._sync_room_occupancy(v_room.id);
  select * into v_room from public.game_room_instances where id = v_room.id;
  delete from public.hardcore_queue where user_id = v_user_id;

  return json_build_object(
    'queued', false,
    'room_instance_id', v_room.id,
    'instance_number', v_room.instance_number,
    'real_player_count', coalesce(v_occ, v_room.real_player_count),
    'leader_radius', v_room.leader_radius,
    'room_type', 'hardcore',
    'match_generation', coalesce(v_room.match_generation, 1),
    'admin_spectator_seat', v_is_admin
  );
end;
$$;

revoke all on function public.join_hardcore_universe() from public, anon;
grant execute on function public.join_hardcore_universe() to authenticated;

notify pgrst, 'reload schema';
