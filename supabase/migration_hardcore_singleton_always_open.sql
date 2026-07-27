-- =============================================================================
-- Quasar.io — Hardcore: single always-open universe
-- - One non-load-test hardcore room only (no 2nd pool when leader ≥ 280)
-- - Stay open on close/empty (soft reset + match_generation bump)
-- - Seat cap from room_game_tuning.maxPlayers (0–100, default 20)
-- Run once after migration_hardcore_admin_seat_exempt.sql
-- =============================================================================

-- 1) Capacity column allows up to 100 seats
alter table public.game_room_instances
  drop constraint if exists game_room_instances_player_count_check;

alter table public.game_room_instances
  add constraint game_room_instances_player_count_check
  check (
    real_player_count >= 0
    and real_player_count <= 100
  );

-- 2) Cap from admin room tuning (JSON maxPlayers)
create or replace function public._hardcore_max_players()
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v int;
begin
  begin
    select nullif(trim(config->>'maxPlayers'), '')::int
    into v
    from public.room_game_tuning
    where room_type = 'hardcore'
    limit 1;
  exception when others then
    v := null;
  end;
  return greatest(0, least(100, coalesce(v, 20)));
end;
$$;

revoke all on function public._hardcore_max_players()
  from public, anon, authenticated;

create or replace function public._max_players_for_room_type(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if lower(coalesce(nullif(trim(p_room), ''), '')) = 'hardcore' then
    return public._hardcore_max_players();
  end if;
  return public._max_real_players_per_room();
exception when undefined_function then
  if lower(coalesce(nullif(trim(p_room), ''), '')) = 'hardcore' then
    return public._hardcore_max_players();
  end if;
  return 10;
end;
$$;

revoke all on function public._max_players_for_room_type(text)
  from public, anon, authenticated;

-- Ensure tuning row has maxPlayers default 20
update public.room_game_tuning
set
  config = config || jsonb_build_object(
    'maxPlayers',
    coalesce((config->>'maxPlayers')::int, 20)
  ),
  updated_at = timezone('utc', now())
where room_type = 'hardcore'
  and (
    config->>'maxPlayers' is null
    or nullif(trim(config->>'maxPlayers'), '') is null
  );

-- 3) Singleton: keep one live hardcore room; close extras
create or replace function public._ensure_hardcore_singleton()
returns public.game_room_instances
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_id uuid;
begin
  -- Prefer lowest instance_number, non-load-test
  select id into v_id
  from public.game_room_instances gri
  where gri.room_type = 'hardcore'
    and coalesce(gri.is_load_test, false) = false
  order by gri.instance_number asc, gri.created_at asc
  limit 1
  for update;

  if v_id is null then
    insert into public.game_room_instances (
      room_type,
      instance_number,
      real_player_count,
      leader_radius,
      peak_leader_radius,
      match_generation,
      status,
      is_load_test
    )
    values ('hardcore', 1, 0, 25, 25, 1, 'open', false)
    returning * into v_room;
    return v_room;
  end if;

  -- Retire duplicate live hardcore rooms (keep singleton only).
  -- Mark as load-test so keep-open trigger does not revive them.
  update public.game_room_instances
  set
    is_load_test = true,
    status = 'closed',
    updated_at = timezone('utc', now())
  where room_type = 'hardcore'
    and coalesce(is_load_test, false) = false
    and id <> v_id;

  update public.game_room_instances
  set
    status = 'open',
    instance_number = 1,
    updated_at = timezone('utc', now())
  where id = v_id
  returning * into v_room;

  return v_room;
end;
$$;

revoke all on function public._ensure_hardcore_singleton()
  from public, anon, authenticated;

-- Soft-open: never leave the live hardcore room in status=closed
create or replace function public._trg_hardcore_keep_open()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.room_type = 'hardcore'
     and coalesce(new.is_load_test, false) = false
     and new.status = 'closed'
  then
    new.status := 'open';
    new.leader_radius := 25;
    new.peak_leader_radius := 25;
    new.leader_radius_synced_at := null;
    new.real_player_count := 0;
    new.match_generation := coalesce(new.match_generation, 0) + 1;
    new.match_started_at := null;
    new.cosmic_seed := null;
    new.updated_at := timezone('utc', now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_hardcore_keep_open on public.game_room_instances;
create trigger trg_hardcore_keep_open
  before update on public.game_room_instances
  for each row
  execute function public._trg_hardcore_keep_open();

-- Bootstrap singleton now
do $$
declare
  v public.game_room_instances%rowtype;
begin
  v := public._ensure_hardcore_singleton();
end $$;

-- 4) Promote — no leader-280 gate; dynamic cap; skip admins without stalling forever
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

  -- Always-open singleton: reopen if somehow closed
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

    -- Admins join via join_hardcore (no seat); drop from queue and try next
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

-- 5) Join — single universe, no leader-280 second pool
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

  -- Admin never consumes a seat — always enter the singleton
  if v_is_admin then
    insert into public.game_room_members (room_instance_id, user_id)
    values (v_room.id, v_user_id);
    v_occ := public._sync_room_occupancy(v_room.id);
    select * into v_room from public.game_room_instances where id = v_room.id;
    delete from public.hardcore_queue where user_id = v_user_id;

    return json_build_object(
      'queued', false,
      'room_instance_id', v_room.id,
      'instance_number', 1,
      'real_player_count', coalesce(v_occ, v_room.real_player_count),
      'leader_radius', v_room.leader_radius,
      'room_type', 'hardcore',
      'match_generation', coalesce(v_room.match_generation, 1),
      'admin_spectator_seat', true
    );
  end if;

  -- Seat available (no leader-radius gate) → join
  if v_cap > 0 and coalesce(v_occ, 0) < v_cap then
    insert into public.game_room_members (room_instance_id, user_id)
    values (v_room.id, v_user_id);
    v_occ := public._sync_room_occupancy(v_room.id);
    select * into v_room from public.game_room_instances where id = v_room.id;
    delete from public.hardcore_queue where user_id = v_user_id;

    return json_build_object(
      'queued', false,
      'room_instance_id', v_room.id,
      'instance_number', 1,
      'real_player_count', coalesce(v_occ, v_room.real_player_count),
      'leader_radius', v_room.leader_radius,
      'room_type', 'hardcore',
      'match_generation', coalesce(v_room.match_generation, 1)
    );
  end if;

  -- Full (or cap 0) → live queue for this single universe
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

-- 6) Queue status — promote into singleton only (no leader filter)
create or replace function public.get_hardcore_queue_status()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.hardcore_queue%rowtype;
  v_pos int;
  v_room public.game_room_instances%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_row
  from public.hardcore_queue
  where user_id = v_uid;

  if not found then
    return json_build_object('status', 'idle');
  end if;

  if v_row.admitted_room_id is not null then
    select * into v_room
    from public.game_room_instances
    where id = v_row.admitted_room_id;

    if exists (
      select 1 from public.game_room_members
      where room_instance_id = v_row.admitted_room_id
        and user_id = v_uid
        and left_at is null
    ) then
      return json_build_object(
        'status', 'admitted',
        'room_instance_id', v_row.admitted_room_id,
        'instance_number', 1,
        'real_player_count', coalesce(v_room.real_player_count, 1),
        'leader_radius', coalesce(v_room.leader_radius, 25),
        'room_type', 'hardcore',
        'match_generation', coalesce(
          v_row.match_generation,
          v_room.match_generation,
          1
        )
      );
    end if;

    delete from public.hardcore_queue where user_id = v_uid;
    return json_build_object('status', 'idle');
  end if;

  v_room := public._ensure_hardcore_singleton();
  perform public._promote_hardcore_queue(v_room.id);

  select * into v_row
  from public.hardcore_queue
  where user_id = v_uid;

  if not found then
    return json_build_object('status', 'idle');
  end if;

  if v_row.admitted_room_id is not null then
    select * into v_room
    from public.game_room_instances
    where id = v_row.admitted_room_id;

    return json_build_object(
      'status', 'admitted',
      'room_instance_id', v_row.admitted_room_id,
      'instance_number', 1,
      'real_player_count', coalesce(v_room.real_player_count, 1),
      'leader_radius', coalesce(v_room.leader_radius, 25),
      'room_type', 'hardcore',
      'match_generation', coalesce(
        v_row.match_generation,
        v_room.match_generation,
        1
      )
    );
  end if;

  v_pos := public._hardcore_queue_position(v_uid);

  return json_build_object(
    'status', 'queued',
    'position', v_pos,
    'room_type', 'hardcore'
  );
end;
$$;

revoke all on function public.get_hardcore_queue_status() from public, anon;
grant execute on function public.get_hardcore_queue_status() to authenticated;

-- 7) Kill alive clamp follows hardcore cap (not hard-coded 20)
create or replace function public.apply_hardcore_kill_reward(
  p_room_instance_id uuid,
  p_prey_user_id uuid,
  p_alive_count int default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_gen int;
  v_alive int;
  v_delta int;
  v_new int;
  v_cap int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_room_instance_id is null or p_prey_user_id is null then
    raise exception 'invalid_args';
  end if;
  if p_prey_user_id = v_uid then
    raise exception 'cannot_kill_self';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found then
    raise exception 'room_not_found';
  end if;
  if lower(v_room.room_type) <> 'hardcore' then
    raise exception 'not_hardcore_room';
  end if;

  if not exists (
    select 1 from public.game_room_members
    where room_instance_id = p_room_instance_id
      and user_id = v_uid
      and (
        left_at is null
        or left_at >= timezone('utc', now()) - interval '2 hours'
      )
  ) then
    raise exception 'not_room_member';
  end if;

  v_cap := greatest(1, public._hardcore_max_players());

  v_alive := coalesce(
    nullif(p_alive_count, 0),
    (
      select count(*)::int
      from public.game_room_members
      where room_instance_id = p_room_instance_id
        and left_at is null
    ),
    1
  );
  v_alive := greatest(1, least(v_cap, v_alive));

  if v_alive >= greatest(2, least(v_cap, public._economy_cfg_int('hardcoreArenaMinAlive', 6))) then
    v_delta := greatest(0, public._economy_cfg_int('rewardHardcoreKill', 4));
  else
    v_delta := greatest(
      0,
      public._economy_cfg_int('rewardHardcoreKillLowPop', 2)
    );
  end if;

  v_gen := coalesce(v_room.match_generation, 1);

  begin
    insert into public.hardcore_kill_claims (
      predator_id, prey_id, room_instance_id, match_generation, diamond_delta
    ) values (v_uid, p_prey_user_id, p_room_instance_id, v_gen, v_delta);
  exception when unique_violation then
    select diamonds into v_new from public.profiles where id = v_uid;
    return coalesce(v_new, 0);
  end;

  perform public._allow_trusted_profile_write();
  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new;

  return coalesce(v_new, 0);
end;
$$;

revoke all on function public.apply_hardcore_kill_reward(uuid, uuid, int)
  from public, anon, authenticated;
grant execute on function public.apply_hardcore_kill_reward(uuid, uuid, int)
  to authenticated;

create or replace function public.apply_hardcore_kill_reward(
  p_room_instance_id uuid,
  p_prey_user_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.apply_hardcore_kill_reward(
    p_room_instance_id,
    p_prey_user_id,
    null
  );
end;
$$;

revoke all on function public.apply_hardcore_kill_reward(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.apply_hardcore_kill_reward(uuid, uuid)
  to authenticated;

notify pgrst, 'reload schema';
