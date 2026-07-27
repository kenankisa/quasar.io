-- =============================================================================
-- Quasar.io — Hardcore Arena Test (isolated load-test universe)
-- Decisions: economy isolated (1A); live rules mirrored on Arena Test
-- (softcap / spawn / food pop / AFK / seats / size-only win). Force = size/absorb.
-- After this file, also run migration_hardcore_arena_test_parity.sql.
-- Run once in Supabase SQL Editor after hardcore singleton + load-test migrations.
-- =============================================================================

-- 0) Allow hardcore victory-sized leader radius (600+) on room rows
do $$
begin
  alter table public.game_room_instances
    drop constraint if exists game_room_instances_leader_radius_check;
exception when undefined_object then
  null;
end $$;

alter table public.game_room_instances
  add constraint game_room_instances_leader_radius_check
  check (leader_radius >= 0 and leader_radius <= 900);

-- =============================================================================

-- 1) Dedicated test queue (does not pollute live hardcore_queue)
create table if not exists public.hardcore_test_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  enqueued_at timestamptz not null default timezone('utc', now()),
  admitted_room_id uuid references public.game_room_instances (id) on delete set null,
  admitted_at timestamptz,
  match_generation int
);

create index if not exists hardcore_test_queue_waiting_idx
  on public.hardcore_test_queue (enqueued_at asc)
  where admitted_room_id is null;

alter table public.hardcore_test_queue enable row level security;

drop policy if exists hardcore_test_queue_select_own on public.hardcore_test_queue;
create policy hardcore_test_queue_select_own
  on public.hardcore_test_queue for select to authenticated
  using (user_id = auth.uid());

-- 2) Force-command mailbox (sims / clients poll + claim)
create table if not exists public.hardcore_arena_test_commands (
  id uuid primary key default gen_random_uuid(),
  room_instance_id uuid not null references public.game_room_instances (id) on delete cascade,
  kind text not null check (kind in ('set_radius', 'force_absorb')),
  target_user_id uuid references auth.users (id) on delete cascade,
  predator_id uuid references auth.users (id) on delete cascade,
  prey_id uuid references auth.users (id) on delete cascade,
  radius double precision,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  claimed_at timestamptz,
  claimed_by uuid references auth.users (id) on delete set null
);

create index if not exists hardcore_arena_test_commands_pending_idx
  on public.hardcore_arena_test_commands (room_instance_id, created_at asc)
  where claimed_at is null;

alter table public.hardcore_arena_test_commands enable row level security;

drop policy if exists hardcore_arena_test_commands_select_member
  on public.hardcore_arena_test_commands;
create policy hardcore_arena_test_commands_select_member
  on public.hardcore_arena_test_commands for select to authenticated
  using (
    exists (
      select 1
      from public.game_room_members grm
      where grm.room_instance_id = hardcore_arena_test_commands.room_instance_id
        and grm.user_id = auth.uid()
        and grm.left_at is null
    )
    or public._is_admin_user(auth.uid())
  );

-- 3) Seat occupancy for test arena: count sims + humans, exclude admins
create or replace function public._room_hardcore_test_seat_occupancy(p_room_id uuid)
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
    and not coalesce(public._is_admin_user(grm.user_id), false);
$$;

revoke all on function public._room_hardcore_test_seat_occupancy(uuid)
  from public, anon, authenticated;

-- 4) Ensure one open hardcore is_load_test room
create or replace function public._ensure_hardcore_load_test_singleton()
returns public.game_room_instances
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_next int;
begin
  select *
  into v_room
  from public.game_room_instances
  where room_type = 'hardcore'
    and coalesce(is_load_test, false) = true
    and status = 'open'
  order by instance_number asc
  limit 1;

  if found then
    return v_room;
  end if;

  select coalesce(max(instance_number), 0) + 1
  into v_next
  from public.game_room_instances
  where room_type = 'hardcore'
    and coalesce(is_load_test, false) = true;

  insert into public.game_room_instances (
    room_type,
    instance_number,
    real_player_count,
    leader_radius,
    status,
    is_load_test,
    match_generation
  )
  values (
    'hardcore',
    greatest(1, coalesce(v_next, 1)),
    0,
    25,
    'open',
    true,
    1
  )
  returning * into v_room;

  return v_room;
end;
$$;

revoke all on function public._ensure_hardcore_load_test_singleton()
  from public, anon, authenticated;

-- 5) Promote waiting sims into the test room
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
     or v_room.status <> 'open' then
    return;
  end if;

  begin
    v_cap := greatest(0, public._hardcore_max_players());
  exception when others then
    v_cap := 20;
  end;

  loop
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

create or replace function public._hardcore_test_queue_position(p_user_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select r.pos::int
      from (
        select
          user_id,
          row_number() over (order by enqueued_at asc) as pos
        from public.hardcore_test_queue
        where admitted_room_id is null
      ) r
      where r.user_id = p_user_id
    ),
    0
  );
$$;

revoke all on function public._hardcore_test_queue_position(uuid)
  from public, anon, authenticated;

-- 6) Join test universe (sims + admin; never touches live singleton)
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

  begin
    v_cap := greatest(0, public._hardcore_max_players());
  exception when others then
    v_cap := 20;
  end;

  v_occ := public._room_hardcore_test_seat_occupancy(v_room.id);

  -- Admin: always enter, no seat
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

  -- Sim: seat available → join; else queue
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

-- Queue status / admit poll for sims waiting outside
create or replace function public.get_hardcore_test_queue_status()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.hardcore_test_queue%rowtype;
  v_room public.game_room_instances%rowtype;
  v_pos int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_room := public._ensure_hardcore_load_test_singleton();
  perform public._promote_hardcore_test_queue(v_room.id);

  select * into v_row
  from public.hardcore_test_queue
  where user_id = v_uid;

  if not found then
    -- Already a member?
    if exists (
      select 1 from public.game_room_members
      where room_instance_id = v_room.id
        and user_id = v_uid
        and left_at is null
    ) then
      select * into v_room from public.game_room_instances where id = v_room.id;
      return json_build_object(
        'queued', false,
        'admitted', true,
        'room_instance_id', v_room.id,
        'id', v_room.id,
        'instance_number', coalesce(v_room.instance_number, 1),
        'real_player_count', coalesce(v_room.real_player_count, 0),
        'leader_radius', coalesce(v_room.leader_radius, 25),
        'room_type', 'hardcore',
        'status', v_room.status,
        'is_load_test', true,
        'match_generation', coalesce(v_room.match_generation, 1)
      );
    end if;
    return json_build_object('queued', false, 'admitted', false);
  end if;

  if v_row.admitted_room_id is not null then
    select * into v_room
    from public.game_room_instances
    where id = v_row.admitted_room_id;
    delete from public.hardcore_test_queue where user_id = v_uid;
    return json_build_object(
      'queued', false,
      'admitted', true,
      'room_instance_id', v_room.id,
      'id', v_room.id,
      'instance_number', coalesce(v_room.instance_number, 1),
      'real_player_count', coalesce(v_room.real_player_count, 0),
      'leader_radius', coalesce(v_room.leader_radius, 25),
      'room_type', 'hardcore',
      'status', v_room.status,
      'is_load_test', true,
      'match_generation', coalesce(v_room.match_generation, 1)
    );
  end if;

  v_pos := public._hardcore_test_queue_position(v_uid);
  return json_build_object(
    'queued', true,
    'position', v_pos,
    'room_type', 'hardcore',
    'is_load_test', true
  );
end;
$$;

revoke all on function public.get_hardcore_test_queue_status() from public, anon;
grant execute on function public.get_hardcore_test_queue_status() to authenticated;

create or replace function public.leave_hardcore_test_queue()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  delete from public.hardcore_test_queue where user_id = v_uid;
end;
$$;

revoke all on function public.leave_hardcore_test_queue() from public, anon;
grant execute on function public.leave_hardcore_test_queue() to authenticated;

-- 7) Admin ops snapshot for test arena
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
  v_min_alive int := 6;
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
    v_min_alive := greatest(
      2,
      least(20, public._economy_cfg_int('hardcoreArenaMinAlive', 6))
    );
  exception when others then
    v_min_alive := 6;
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
    'players', coalesce(v_players, '[]'::json),
    'queue', coalesce(v_queue, '[]'::json),
    'queue_count', coalesce(v_queue_count, 0),
    'victory_radius', 600,
    'victory_min_alive', v_min_alive,
    'victory_stable_seconds', 20,
    'victory_min_pvp_fraction', 0.35,
    'economy_isolated', true,
    'fetched_at', timezone('utc', now())
  );
end;
$$;

revoke all on function public.get_admin_hardcore_arena_test_ops()
  from public, anon;
grant execute on function public.get_admin_hardcore_arena_test_ops()
  to authenticated;

-- 8) Admin force commands
create or replace function public.admin_hardcore_test_set_radius(
  p_user_id uuid,
  p_radius double precision
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_id uuid;
  v_r double precision;
begin
  perform public._require_admin();
  if p_user_id is null then
    raise exception 'invalid_args';
  end if;
  v_r := greatest(10, least(900, coalesce(p_radius, 25)));
  v_room := public._ensure_hardcore_load_test_singleton();

  if not exists (
    select 1 from public.game_room_members
    where room_instance_id = v_room.id
      and user_id = p_user_id
      and left_at is null
  ) then
    raise exception 'not_room_member';
  end if;

  insert into public.hardcore_arena_test_commands (
    room_instance_id, kind, target_user_id, radius, created_by
  ) values (v_room.id, 'set_radius', p_user_id, v_r, v_admin)
  returning id into v_id;

  return json_build_object(
    'ok', true,
    'command_id', v_id,
    'user_id', p_user_id,
    'radius', v_r,
    'room_id', v_room.id
  );
end;
$$;

revoke all on function public.admin_hardcore_test_set_radius(uuid, double precision)
  from public, anon;
grant execute on function public.admin_hardcore_test_set_radius(uuid, double precision)
  to authenticated;

create or replace function public.admin_hardcore_test_force_absorb(
  p_predator_id uuid,
  p_prey_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_id uuid;
begin
  perform public._require_admin();
  if p_predator_id is null or p_prey_id is null or p_predator_id = p_prey_id then
    raise exception 'invalid_args';
  end if;
  v_room := public._ensure_hardcore_load_test_singleton();

  if not exists (
    select 1 from public.game_room_members
    where room_instance_id = v_room.id
      and user_id = p_predator_id
      and left_at is null
  ) then
    raise exception 'predator_not_in_room';
  end if;
  if not exists (
    select 1 from public.game_room_members
    where room_instance_id = v_room.id
      and user_id = p_prey_id
      and left_at is null
  ) then
    raise exception 'prey_not_in_room';
  end if;

  insert into public.hardcore_arena_test_commands (
    room_instance_id, kind, predator_id, prey_id, created_by
  ) values (v_room.id, 'force_absorb', p_predator_id, p_prey_id, v_admin)
  returning id into v_id;

  return json_build_object(
    'ok', true,
    'command_id', v_id,
    'predator_id', p_predator_id,
    'prey_id', p_prey_id,
    'room_id', v_room.id
  );
end;
$$;

revoke all on function public.admin_hardcore_test_force_absorb(uuid, uuid)
  from public, anon;
grant execute on function public.admin_hardcore_test_force_absorb(uuid, uuid)
  to authenticated;

-- Claim pending commands for the caller's user (sim or admin in room)
create or replace function public.claim_hardcore_test_commands()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room_id uuid;
  v_out json;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select grm.room_instance_id into v_room_id
  from public.game_room_members grm
  join public.game_room_instances gri on gri.id = grm.room_instance_id
  where grm.user_id = v_uid
    and grm.left_at is null
    and lower(gri.room_type) = 'hardcore'
    and coalesce(gri.is_load_test, false) = true
  order by grm.joined_at desc
  limit 1;

  if v_room_id is null then
    return '[]'::json;
  end if;

  with pending as (
    select c.id
    from public.hardcore_arena_test_commands c
    where c.room_instance_id = v_room_id
      and c.claimed_at is null
      and (
        (c.kind = 'set_radius' and c.target_user_id = v_uid)
        or (
          c.kind = 'force_absorb'
          and (c.predator_id = v_uid or c.prey_id = v_uid)
        )
      )
    order by c.created_at asc
    for update skip locked
  ),
  claimed as (
    update public.hardcore_arena_test_commands c
    set claimed_at = timezone('utc', now()), claimed_by = v_uid
    from pending p
    where c.id = p.id
    returning
      c.id,
      c.kind,
      c.target_user_id,
      c.predator_id,
      c.prey_id,
      c.radius,
      c.created_at
  )
  select coalesce(json_agg(row_to_json(claimed)), '[]'::json)
  into v_out
  from claimed;

  return coalesce(v_out, '[]'::json);
end;
$$;

revoke all on function public.claim_hardcore_test_commands() from public, anon;
grant execute on function public.claim_hardcore_test_commands() to authenticated;

-- Cleanup members/queue when stopping a test run
create or replace function public.admin_hardcore_arena_test_reset()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_removed int := 0;
begin
  perform public._require_admin();
  v_room := public._ensure_hardcore_load_test_singleton();

  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = v_room.id
    and left_at is null;
  get diagnostics v_removed = row_count;

  -- WHERE required (safe-updates / PostgREST-style guards → 21000)
  delete from public.hardcore_test_queue where true;
  delete from public.hardcore_arena_test_commands
  where room_instance_id = v_room.id;

  update public.game_room_instances
  set
    leader_radius = 25,
    real_player_count = 0,
    status = 'open',
    match_generation = coalesce(match_generation, 1) + 1
  where id = v_room.id;

  return json_build_object(
    'ok', true,
    'room_id', v_room.id,
    'members_cleared', v_removed
  );
end;
$$;

revoke all on function public.admin_hardcore_arena_test_reset() from public, anon;
grant execute on function public.admin_hardcore_arena_test_reset() to authenticated;

-- 9) Economy isolation: kill reward no-op on load-test hardcore
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

  -- Arena Test (1A): no diamonds / claims on load-test hardcore
  if coalesce(v_room.is_load_test, false) then
    select diamonds into v_new from public.profiles where id = v_uid;
    return coalesce(v_new, 0);
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
  v_alive := greatest(1, least(100, v_alive));

  if v_alive >= greatest(2, least(20, public._economy_cfg_int('hardcoreArenaMinAlive', 6))) then
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
  from public, anon;
grant execute on function public.apply_hardcore_kill_reward(uuid, uuid, int)
  to authenticated;

-- Also keep 2-arg overload if present callers use it
do $$
begin
  execute $fn$
    create or replace function public.apply_hardcore_kill_reward(
      p_room_instance_id uuid,
      p_prey_user_id uuid
    )
    returns int
    language plpgsql
    security definer
    set search_path = public
    as $body$
    begin
      return public.apply_hardcore_kill_reward(
        p_room_instance_id, p_prey_user_id, null
      );
    end;
    $body$;
  $fn$;
exception when others then
  raise notice '2-arg apply_hardcore_kill_reward wrap skipped: %', sqlerrm;
end $$;

-- 10) apply_match_result: skip economy side effects for load-test rooms
do $$
declare
  v_def text;
  v_oid oid;
begin
  begin
    v_oid := 'public.apply_match_result(text,int,boolean,uuid)'::regprocedure;
    v_def := pg_get_functiondef(v_oid);
  exception when undefined_function then
    raise notice 'apply_match_result missing — skip load-test isolation patch';
    return;
  end;

  if position('is_load_test_economy_skip' in v_def) > 0 then
    raise notice 'apply_match_result already has load-test skip';
    return;
  end if;

  -- Inject early return after auth / room resolution if we find a known marker.
  -- Prefer inserting after v_uid null check when p_room_instance_id is set.
  if position('if v_uid is null then' in v_def) > 0
     and position('is_load_test_economy_skip' in v_def) = 0 then
    v_def := replace(
      v_def,
      'if v_uid is null then
    raise exception ''not authenticated'';
  end if;',
      'if v_uid is null then
    raise exception ''not authenticated'';
  end if;

  -- is_load_test_economy_skip: Arena Test / load-test rooms award nothing
  if p_room_instance_id is not null then
    if exists (
      select 1
      from public.game_room_instances gri
      where gri.id = p_room_instance_id
        and coalesce(gri.is_load_test, false) = true
    ) then
      return (
        select diamonds from public.profiles where id = v_uid
      );
    end if;
  end if;'
    );
  end if;

  begin
    execute v_def;
  exception when others then
    raise notice 'apply_match_result load-test patch failed: %', sqlerrm;
  end;
end $$;

-- 11) Soft-open: keep load-test hardcore from staying closed after empty leave
create or replace function public._hardcore_test_keep_open()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(new.room_type) = 'hardcore'
     and coalesce(new.is_load_test, false) = true
     and new.status = 'closed' then
    new.status := 'open';
    new.leader_radius := least(coalesce(new.leader_radius, 25), 25);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_hardcore_test_keep_open on public.game_room_instances;
create trigger trg_hardcore_test_keep_open
  before update on public.game_room_instances
  for each row
  execute function public._hardcore_test_keep_open();

comment on function public.join_hardcore_test_universe() is
  'Join isolated Hardcore Arena Test room (sim or admin). Live singleton untouched.';
comment on function public.get_admin_hardcore_arena_test_ops() is
  'Admin snapshot for Hardcore Arena Test: inside seats + outside queue.';

-- 12) Leader radius: hardcore may reach victory size 600 (+ headroom)
create or replace function public.update_room_leader_radius(
  p_room_instance_id uuid,
  p_leader_radius int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_new int;
  v_elapsed_sec double precision;
  v_time_cap int;
  v_match_start timestamptz;
  v_hard_cap int := 550;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found or v_room.status <> 'open' then
    return;
  end if;

  if lower(v_room.room_type) = 'hardcore' then
    v_hard_cap := 900;
  end if;

  if p_leader_radius < 0 or p_leader_radius > v_hard_cap then
    raise exception 'invalid leader_radius';
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

  if v_room.leader_radius_synced_at is not null
     and v_room.leader_radius_synced_at > timezone('utc', now()) - interval '4 seconds' then
    return;
  end if;

  v_match_start := coalesce(v_room.match_started_at, v_room.created_at);
  v_elapsed_sec := greatest(
    0,
    extract(epoch from (timezone('utc', now()) - v_match_start))
  );

  -- Hardcore / load-test: looser time cap so force-grow tests can climb.
  if lower(v_room.room_type) = 'hardcore' then
    v_time_cap := v_hard_cap;
  else
    v_time_cap := least(
      v_hard_cap,
      25 + floor(v_elapsed_sec * 1.8)::int
    );
  end if;

  v_new := least(
    v_time_cap,
    v_hard_cap,
    greatest(
      v_room.leader_radius,
      least(
        p_leader_radius,
        v_room.leader_radius + case
          when lower(v_room.room_type) = 'hardcore' then 200
          else 50
        end
      )
    )
  );

  if v_new <= v_room.leader_radius then
    update public.game_room_instances
    set leader_radius_synced_at = timezone('utc', now())
    where id = p_room_instance_id;
    return;
  end if;

  update public.game_room_instances
  set
    leader_radius = v_new,
    peak_leader_radius = greatest(coalesce(peak_leader_radius, 0), v_new),
    leader_radius_synced_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

grant execute on function public.update_room_leader_radius(uuid, int)
  to authenticated;
