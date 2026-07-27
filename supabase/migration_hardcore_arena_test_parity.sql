-- =============================================================================
-- Quasar.io — Hardcore Arena Test ↔ live Hardcore rule parity
-- Run once after migration_hardcore_arena_test.sql
--
-- Aligns:
--   • keep-open soft reset (match_generation / peak / seed)
--   • occupancy sync counting sims in load-test hardcore
--   • leave_game_room → promote test (+ live) queue when a seat frees
--   • test promote: reopen if closed, skip already-seated
--   • admin ops snapshot reads live hardcoreArena tuning knobs
-- Economy isolation stays intentional (is_load_test skip).
-- =============================================================================

-- 1) Occupancy: live hardcore = humans only; Arena Test = sims + humans (no admin)
create or replace function public._sync_room_occupancy(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_humans int;
  v_room_type text;
  v_is_load_test boolean := false;
  v_cap int;
begin
  select room_type, coalesce(is_load_test, false)
  into v_room_type, v_is_load_test
  from public.game_room_instances
  where id = p_room_id;

  if lower(coalesce(v_room_type, '')) = 'hardcore' and v_is_load_test then
    begin
      v_humans := public._room_hardcore_test_seat_occupancy(p_room_id);
    exception when undefined_function then
      begin
        v_humans := public._room_occupancy(p_room_id);
      exception when undefined_function then
        v_humans := 0;
      end;
    end;
  elsif lower(coalesce(v_room_type, '')) = 'hardcore' then
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

-- 2) Keep-open parity with live hardcore singleton soft reset
create or replace function public._hardcore_test_keep_open()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(new.room_type) = 'hardcore'
     and coalesce(new.is_load_test, false) = true
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

drop trigger if exists trg_hardcore_test_keep_open on public.game_room_instances;
create trigger trg_hardcore_test_keep_open
  before update on public.game_room_instances
  for each row
  execute function public._hardcore_test_keep_open();

-- 3) Promote test queue: reopen + skip seated (mirrors live promote loop)
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

-- 4) leave_game_room: free seat → promote live + test hardcore queues
create or replace function public.leave_game_room(p_room_instance_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_member record;
  v_occ int;
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

    v_occ := public._sync_room_occupancy(v_member.room_instance_id);

    if coalesce(v_occ, 0) <= 0 then
      update public.game_room_instances
      set
        status = 'closed',
        real_player_count = 0,
        leader_radius = 25,
        peak_leader_radius = 25,
        leader_radius_synced_at = null,
        updated_at = timezone('utc', now())
      where id = v_member.room_instance_id
        and status = 'open';
    else
      begin
        perform public._promote_hardcore_queue(v_member.room_instance_id);
      exception when others then
        null;
      end;
      begin
        perform public._promote_hardcore_test_queue(v_member.room_instance_id);
      exception when others then
        null;
      end;
    end if;
  end loop;
end;
$$;

revoke all on function public.leave_game_room(uuid) from public, anon;
grant execute on function public.leave_game_room(uuid) to authenticated;

-- 5) Admin ops: read live hardcoreArena tuning (same knobs as live universe)
create or replace function public.get_admin_hardcore_arena_test_ops()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_max int := 20;
  v_seats int := 0;
  v_queue_count int := 0;
  v_players json := '[]'::json;
  v_queue json := '[]'::json;
  v_cfg jsonb := '{}'::jsonb;
  v_arena jsonb := '{}'::jsonb;
  v_victory_radius int := 600;
  v_min_alive int := 6;
  v_stable double precision := 20;
  v_pvp double precision := 0.35;
  v_spawn double precision := 12;
  v_low_pop_cap double precision := 450;
  v_late_food_r double precision := 450;
  v_late_food_m double precision := 0.5;
begin
  perform public._require_admin();
  v_room := public._ensure_hardcore_load_test_singleton();
  perform public._promote_hardcore_test_queue(v_room.id);

  begin
    v_max := greatest(0, public._hardcore_max_players());
  exception when others then
    v_max := 20;
  end;

  begin
    select coalesce(config, '{}'::jsonb)
    into v_cfg
    from public.room_game_tuning
    where room_type = 'hardcore'
    limit 1;
  exception when others then
    v_cfg := '{}'::jsonb;
  end;

  v_arena := coalesce(v_cfg->'hardcoreArena', '{}'::jsonb);

  begin
    v_victory_radius := greatest(
      100,
      least(900, coalesce((v_cfg->>'victoryRadius')::int, 600))
    );
  exception when others then
    v_victory_radius := 600;
  end;

  begin
    v_min_alive := greatest(
      2,
      least(20, coalesce((v_arena->>'victoryMinAlive')::int, 6))
    );
  exception when others then
    begin
      v_min_alive := greatest(
        2,
        least(20, public._economy_cfg_int('hardcoreArenaMinAlive', 6))
      );
    exception when others then
      v_min_alive := 6;
    end;
  end;

  begin
    v_stable := greatest(
      0,
      least(120, coalesce((v_arena->>'victoryStableSeconds')::double precision, 20))
    );
  exception when others then
    v_stable := 20;
  end;

  begin
    v_pvp := greatest(
      0,
      least(1, coalesce((v_arena->>'victoryMinPvpMassFraction')::double precision, 0.35))
    );
  exception when others then
    v_pvp := 0.35;
  end;

  begin
    v_spawn := greatest(
      3,
      least(30, coalesce((v_arena->>'spawnProtectionSeconds')::double precision, 12))
    );
  exception when others then
    v_spawn := 12;
  end;

  begin
    v_low_pop_cap := greatest(
      100,
      least(700, coalesce((v_arena->>'lowPopRadiusCap')::double precision, 450))
    );
  exception when others then
    v_low_pop_cap := 450;
  end;

  begin
    v_late_food_r := greatest(
      100,
      least(700, coalesce((v_arena->>'lateFoodSoftcapRadius')::double precision, 450))
    );
  exception when others then
    v_late_food_r := 450;
  end;

  begin
    v_late_food_m := greatest(
      0.1,
      least(1, coalesce((v_arena->>'lateFoodSoftcapMultiplier')::double precision, 0.5))
    );
  exception when others then
    v_late_food_m := 0.5;
  end;

  v_seats := public._room_hardcore_test_seat_occupancy(v_room.id);

  select coalesce(json_agg(row_to_json(t) order by t.joined_at asc), '[]'::json)
  into v_players
  from (
    select
      grm.user_id::text as user_id,
      coalesce(nullif(trim(p.username), ''), '—') as username,
      grm.joined_at,
      coalesce(public._is_admin_user(grm.user_id), false) as is_admin,
      coalesce(public._is_sim_auth_user(grm.user_id), false) as is_sim
    from public.game_room_members grm
    join public.profiles p on p.id = grm.user_id
    where grm.room_instance_id = v_room.id
      and grm.left_at is null
    order by grm.joined_at asc
  ) t;

  select count(*)::int
  into v_queue_count
  from public.hardcore_test_queue
  where admitted_room_id is null;

  select coalesce(json_agg(row_to_json(t) order by t.position asc), '[]'::json)
  into v_queue
  from (
    select
      row_number() over (order by q.enqueued_at asc)::int as position,
      q.user_id::text as user_id,
      coalesce(nullif(trim(p.username), ''), '—') as username,
      q.enqueued_at
    from public.hardcore_test_queue q
    join public.profiles p on p.id = q.user_id
    where q.admitted_room_id is null
    order by q.enqueued_at asc
    limit 100
  ) t;

  return json_build_object(
    'room_id', v_room.id,
    'status', coalesce(v_room.status, 'missing'),
    'leader_radius', coalesce(v_room.leader_radius, 0),
    'real_player_count', coalesce(v_room.real_player_count, 0),
    'seat_occupancy', coalesce(v_seats, 0),
    'max_players', v_max,
    'match_generation', coalesce(v_room.match_generation, 1),
    'players', coalesce(v_players, '[]'::json),
    'queue', coalesce(v_queue, '[]'::json),
    'queue_count', coalesce(v_queue_count, 0),
    'victory_radius', v_victory_radius,
    'victory_min_alive', v_min_alive,
    'victory_stable_seconds', v_stable,
    'victory_min_pvp_fraction', v_pvp,
    'spawn_protection_seconds', v_spawn,
    'low_pop_radius_cap', v_low_pop_cap,
    'late_food_softcap_radius', v_late_food_r,
    'late_food_softcap_multiplier', v_late_food_m,
    'economy_isolated', true,
    'fetched_at', timezone('utc', now())
  );
end;
$$;

revoke all on function public.get_admin_hardcore_arena_test_ops()
  from public, anon;
grant execute on function public.get_admin_hardcore_arena_test_ops()
  to authenticated;

comment on function public._hardcore_test_keep_open() is
  'Arena Test soft-open: same reset fields as live hardcore keep-open.';
comment on function public.get_admin_hardcore_arena_test_ops() is
  'Admin snapshot for Hardcore Arena Test (live tuning knobs + seats/queue).';
