-- =============================================================================
-- Quasar.io — Hardcore rules v2
-- Players-only, max 20, queue, kill/elim diamonds, win +50 +1 HC point, 1h cooldown
-- Run once in Supabase SQL Editor (after migration_hardcore_universe.sql).
-- =============================================================================

-- 1) Profile columns
alter table public.profiles
  add column if not exists hardcore_points int not null default 0;

alter table public.profiles
  add column if not exists hardcore_cooldown_until timestamptz;

comment on column public.profiles.hardcore_points is
  'Hardcore victories (1 point = 1 hardcore win)';
comment on column public.profiles.hardcore_cooldown_until is
  'Cannot join hardcore until this UTC time (win or elimination)';

-- 2) Capacity: allow up to 20 real players (hardcore)
alter table public.game_room_instances
  drop constraint if exists game_room_instances_player_count_check;

alter table public.game_room_instances
  add constraint game_room_instances_player_count_check
  check (
    real_player_count >= 0
    and real_player_count <= 20
  );

create or replace function public._max_players_for_room_type(p_room text)
returns int
language sql
immutable
as $$
  select case
    when lower(coalesce(nullif(trim(p_room), ''), '')) = 'hardcore' then 20
    else public._max_real_players_per_room()
  end;
$$;

revoke all on function public._max_players_for_room_type(text)
  from public, anon, authenticated;

-- Sync occupancy with per-room-type cap
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
  begin
    v_humans := public._room_human_occupancy(p_room_id);
  exception when undefined_function then
    v_humans := public._room_occupancy(p_room_id);
  end;

  select room_type into v_room_type
  from public.game_room_instances
  where id = p_room_id;

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

-- 3) Queue table
create table if not exists public.hardcore_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  enqueued_at timestamptz not null default timezone('utc', now()),
  admitted_room_id uuid references public.game_room_instances (id) on delete set null,
  admitted_at timestamptz,
  match_generation int
);

create index if not exists hardcore_queue_waiting_idx
  on public.hardcore_queue (enqueued_at asc)
  where admitted_room_id is null;

alter table public.hardcore_queue enable row level security;

drop policy if exists hardcore_queue_select_own on public.hardcore_queue;
create policy hardcore_queue_select_own
  on public.hardcore_queue for select to authenticated
  using (user_id = auth.uid());

-- 4) Kill claims (anti double-claim)
create table if not exists public.hardcore_kill_claims (
  id uuid primary key default gen_random_uuid(),
  predator_id uuid not null references auth.users (id) on delete cascade,
  prey_id uuid not null,
  room_instance_id uuid not null references public.game_room_instances (id) on delete cascade,
  match_generation int not null default 1,
  diamond_delta int not null default 5,
  created_at timestamptz not null default timezone('utc', now()),
  unique (predator_id, prey_id, room_instance_id, match_generation)
);

create index if not exists hardcore_kill_claims_pred_idx
  on public.hardcore_kill_claims (predator_id, created_at desc);

alter table public.hardcore_kill_claims enable row level security;

-- 5) Economy helpers — hardcore specific
create or replace function public._economy_placement_delta(p_room text, p_placement int)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
begin
  if p_placement is null or p_placement < 1 or p_placement > 3 then
    return 0;
  end if;

  if v_room = 'hardcore' then
    -- Only size-600 victory pays; no podium 2/3
    if p_placement = 1 then
      return greatest(0, public._economy_cfg_int('rewardHardcore1', 50));
    end if;
    return 0;
  end if;

  return case v_room
    when 'simple' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardSimple1', 3))
        when 2 then greatest(0, public._economy_cfg_int('rewardSimple2', 2))
        else greatest(0, public._economy_cfg_int('rewardSimple3', 1))
      end
    when 'elite' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardElite1', 10))
        when 2 then greatest(0, public._economy_cfg_int('rewardElite2', 6))
        else greatest(0, public._economy_cfg_int('rewardElite3', 4))
      end
    when 'unique' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardUnique1', 15))
        when 2 then greatest(0, public._economy_cfg_int('rewardUnique2', 10))
        else greatest(0, public._economy_cfg_int('rewardUnique3', 5))
      end
    else
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardNormal1', 5))
        when 2 then greatest(0, public._economy_cfg_int('rewardNormal2', 3))
        else greatest(0, public._economy_cfg_int('rewardNormal3', 2))
      end
  end;
end;
$$;

create or replace function public._economy_elimination_delta(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
  v_loss int;
begin
  if v_room = 'hardcore' then
    return -greatest(0, public._economy_cfg_int('penaltyHardcore', 20));
  end if;
  v_loss := case v_room
    when 'simple' then greatest(0, public._economy_cfg_int('penaltySimple', 0))
    when 'elite' then greatest(0, public._economy_cfg_int('penaltyElite', 3))
    when 'unique' then greatest(0, public._economy_cfg_int('penaltyUnique', 4))
    else greatest(0, public._economy_cfg_int('penaltyNormal', 2))
  end;
  return -v_loss;
end;
$$;

-- 6) Queue helpers
create or replace function public._hardcore_queue_position(p_user_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select q.pos::int
      from (
        select
          user_id,
          row_number() over (order by enqueued_at asc) as pos
        from public.hardcore_queue
        where admitted_room_id is null
      ) q
      where q.user_id = p_user_id
    ),
    0
  );
$$;

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
    v_occ := public._room_human_occupancy(p_room_id);
  exception when undefined_function then
    v_occ := public._room_occupancy(p_room_id);
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

  -- Already seated elsewhere?
  if exists (
    select 1 from public.game_room_members
    where user_id = v_next and left_at is null
  ) then
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

-- 7) join_hardcore_universe
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
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

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

  if coalesce(v_trophies, 0) < 10
     and not public._is_admin_user(v_user_id) then
    raise exception 'hardcore_trophy_lock';
  end if;

  if v_cd is not null and v_cd > timezone('utc', now())
     and not public._is_admin_user(v_user_id) then
    raise exception 'hardcore_cooldown'
      using detail = to_char(v_cd at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
  end if;

  -- Leave other seats / clear prior queue wait (keep admitted row briefly)
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

  -- Prefer an open hardcore room under capacity
  begin
    select *
    into v_room
    from public.game_room_instances gri
    where gri.room_type = 'hardcore'
      and gri.status = 'open'
      and gri.leader_radius < 280
      and not public._room_has_load_test(gri.id)
      and public._room_human_occupancy(gri.id) < v_cap
    order by public._room_human_occupancy(gri.id) desc, gri.instance_number asc
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
      v_occ := public._room_human_occupancy(v_room.id);
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

  -- Any open hardcore room already at cap? → queue (do not open a second pool)
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

  -- No open room — reopen closed or create
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
    'match_generation', coalesce(v_room.match_generation, 1)
  );
end;
$$;

revoke all on function public.join_hardcore_universe() from public, anon;
grant execute on function public.join_hardcore_universe() to authenticated;

-- 8) Queue status / leave
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

    -- Confirm membership still active
    if exists (
      select 1 from public.game_room_members
      where room_instance_id = v_row.admitted_room_id
        and user_id = v_uid
        and left_at is null
    ) then
      return json_build_object(
        'status', 'admitted',
        'room_instance_id', v_row.admitted_room_id,
        'instance_number', coalesce(v_room.instance_number, 1),
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

    -- Stale admission
    delete from public.hardcore_queue where user_id = v_uid;
    return json_build_object('status', 'idle');
  end if;

  -- Try promote into any open hardcore seat (helps if leave missed promote)
  for v_room in
    select *
    from public.game_room_instances
    where room_type = 'hardcore'
      and status = 'open'
      and leader_radius < 280
    order by instance_number asc
  loop
    perform public._promote_hardcore_queue(v_room.id);
  end loop;

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
      'instance_number', coalesce(v_room.instance_number, 1),
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
    'position', v_pos
  );
end;
$$;

revoke all on function public.get_hardcore_queue_status() from public, anon;
grant execute on function public.get_hardcore_queue_status() to authenticated;

create or replace function public.leave_hardcore_queue()
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

  delete from public.hardcore_queue where user_id = v_uid;
end;
$$;

revoke all on function public.leave_hardcore_queue() from public, anon;
grant execute on function public.leave_hardcore_queue() to authenticated;

-- 9) Patch leave_game_room to promote queue (string-safe append via replace)
do $$
declare
  v_def text;
begin
  begin
    v_def := pg_get_functiondef('public.leave_game_room(uuid)'::regprocedure);
  exception when undefined_function then
    return;
  end;

  if position('_promote_hardcore_queue' in v_def) = 0 then
    v_def := replace(
      v_def,
      'if coalesce(v_total, 0) <= 0 then
      update public.game_room_instances
      set
        status = ''closed'',
        real_player_count = 0,
        leader_radius = 25,
        peak_leader_radius = 25,
        leader_radius_synced_at = null,
        updated_at = timezone(''utc'', now())
      where id = v_member.room_instance_id
        and status = ''open'';
    end if;',
      'if coalesce(v_total, 0) <= 0 then
      update public.game_room_instances
      set
        status = ''closed'',
        real_player_count = 0,
        leader_radius = 25,
        peak_leader_radius = 25,
        leader_radius_synced_at = null,
        updated_at = timezone(''utc'', now())
      where id = v_member.room_instance_id
        and status = ''open'';
    else
      begin
        perform public._promote_hardcore_queue(v_member.room_instance_id);
      exception when others then
        null;
      end;
    end if;'
    );
    begin
      execute v_def;
    exception when others then
      raise notice 'leave_game_room promote patch skipped: %', sqlerrm;
    end;
  end if;
end $$;

-- 10) Kill reward RPC
create or replace function public.apply_hardcore_kill_reward(
  p_room_instance_id uuid,
  p_prey_user_id uuid
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
  v_delta int := greatest(0, public._economy_cfg_int('rewardHardcoreKill', 5));
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

revoke all on function public.apply_hardcore_kill_reward(uuid, uuid)
  from public, anon;
grant execute on function public.apply_hardcore_kill_reward(uuid, uuid)
  to authenticated;

-- 11) Patch apply_match_result allowlist + hardcore win/elim side effects
do $$
declare
  v_def text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'apply_match_result missing';
    return;
  end;

  v_def := replace(
    v_def,
    'if v_room not in (''simple'', ''normal'', ''elite'', ''unique'') then',
    'if v_room not in (''simple'', ''normal'', ''elite'', ''unique'', ''hardcore'') then'
  );

  -- Victory verify for hardcore needs higher peak (size 600)
  if position('victory_not_verified' in v_def) > 0
     and position('hardcore'' and v_peak < 550' in v_def) = 0 then
    v_def := replace(
      v_def,
      'if v_kind = ''reward'' and p_placement = 1 then
        if v_peak < 350 then
          raise exception ''victory_not_verified'';
        end if;
      end if;',
      'if v_kind = ''reward'' and p_placement = 1 then
        if v_room = ''hardcore'' then
          if v_peak < 550 then
            raise exception ''victory_not_verified'';
          end if;
        elsif v_peak < 350 then
          raise exception ''victory_not_verified'';
        end if;
      end if;'
    );
  end if;

  -- Inject hardcore_points + cooldown into profile update
  if position('hardcore_points' in v_def) = 0 then
    v_def := replace(
      v_def,
      'trophy_wins_unique = case
      when v_room = ''unique'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_unique, 0) + 1)
      else trophy_wins_unique
    end,
    updated_at = timezone(''utc'', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;',
      'trophy_wins_unique = case
      when v_room = ''unique'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_unique, 0) + 1)
      else trophy_wins_unique
    end,
    hardcore_points = case
      when v_room = ''hardcore'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1
        then coalesce(hardcore_points, 0) + 1
      else hardcore_points
    end,
    hardcore_cooldown_until = case
      when v_room = ''hardcore'' and (
        (v_kind = ''reward'' and coalesce(p_placement, 0) = 1)
        or v_kind = ''penalty''
      ) then timezone(''utc'', now()) + interval ''1 hour''
      else hardcore_cooldown_until
    end,
    updated_at = timezone(''utc'', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;'
    );
  end if;

  -- Hardcore wins count as games_won but skip normal rank_points if helper lacks hardcore
  begin
    execute v_def;
  exception when others then
    raise notice 'apply_match_result hardcore patch failed: %', sqlerrm;
  end;
end $$;

-- Ensure hardcore 1st place increments games_won (won=1 path). If room was excluded
-- from v_won earlier, patch via helper is enough when allowlist includes hardcore.

-- 12) Global leaderboard — hardcore sort
drop function if exists public.get_global_leaderboard(int, text);

create or replace function public.get_global_leaderboard(
  p_limit int default 100,
  p_sort text default 'rank'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 100);
  v_sort text := lower(coalesce(nullif(trim(p_sort), ''), 'rank'));
  v_top json;
  v_local json;
  v_local_rank int;
  v_in_top boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_sort not in ('rank', 'wealth', 'hardcore') then
    v_sort := 'rank';
  end if;

  if v_sort = 'wealth' then
    select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
    into v_top
    from (
      select
        row_number() over (
          order by
            p.diamonds desc,
            coalesce(p.games_won, 0) desc,
            coalesce(p.rank_points, 0) desc,
            p.updated_at desc nulls last
        ) as rank_pos,
        p.id as user_id,
        coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
        p.diamonds,
        coalesce(p.games_won, 0) as games_won,
        coalesce(p.rank_points, 0) as rank_points,
        coalesce(p.hardcore_points, 0) as hardcore_points
      from public.profiles p
      where not public._is_admin_user(p.id)
      order by
        p.diamonds desc,
        coalesce(p.games_won, 0) desc,
        coalesce(p.rank_points, 0) desc,
        p.updated_at desc nulls last
      limit v_limit
    ) t;
  elsif v_sort = 'hardcore' then
    select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
    into v_top
    from (
      select
        row_number() over (
          order by
            coalesce(p.hardcore_points, 0) desc,
            coalesce(p.games_won, 0) desc,
            p.diamonds desc,
            p.updated_at desc nulls last
        ) as rank_pos,
        p.id as user_id,
        coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
        p.diamonds,
        coalesce(p.games_won, 0) as games_won,
        coalesce(p.rank_points, 0) as rank_points,
        coalesce(p.hardcore_points, 0) as hardcore_points
      from public.profiles p
      where not public._is_admin_user(p.id)
        and coalesce(p.hardcore_points, 0) > 0
      order by
        coalesce(p.hardcore_points, 0) desc,
        coalesce(p.games_won, 0) desc,
        p.diamonds desc,
        p.updated_at desc nulls last
      limit v_limit
    ) t;
  else
    select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
    into v_top
    from (
      select
        row_number() over (
          order by
            coalesce(p.rank_points, 0) desc,
            coalesce(p.games_won, 0) desc,
            p.diamonds desc,
            p.updated_at desc nulls last
        ) as rank_pos,
        p.id as user_id,
        coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
        p.diamonds,
        coalesce(p.games_won, 0) as games_won,
        coalesce(p.rank_points, 0) as rank_points,
        coalesce(p.hardcore_points, 0) as hardcore_points
      from public.profiles p
      where not public._is_admin_user(p.id)
      order by
        coalesce(p.rank_points, 0) desc,
        coalesce(p.games_won, 0) desc,
        p.diamonds desc,
        p.updated_at desc nulls last
      limit v_limit
    ) t;
  end if;

  select exists (
    select 1
    from json_array_elements(v_top) e
    where (e->>'user_id')::uuid = v_uid
  ) into v_in_top;

  if not v_in_top then
    if v_sort = 'wealth' then
      select position into v_local_rank
      from (
        select id, row_number() over (
          order by diamonds desc, coalesce(games_won, 0) desc,
                   coalesce(rank_points, 0) desc, updated_at desc nulls last
        ) as position
        from public.profiles
        where not public._is_admin_user(id)
      ) ranked where id = v_uid;
    elsif v_sort = 'hardcore' then
      select position into v_local_rank
      from (
        select id, row_number() over (
          order by coalesce(hardcore_points, 0) desc, coalesce(games_won, 0) desc,
                   diamonds desc, updated_at desc nulls last
        ) as position
        from public.profiles
        where not public._is_admin_user(id)
      ) ranked where id = v_uid;
    else
      select position into v_local_rank
      from (
        select id, row_number() over (
          order by coalesce(rank_points, 0) desc, coalesce(games_won, 0) desc,
                   diamonds desc, updated_at desc nulls last
        ) as position
        from public.profiles
        where not public._is_admin_user(id)
      ) ranked where id = v_uid;
    end if;

    select json_build_object(
      'rank_pos', coalesce(v_local_rank, 0),
      'user_id', p.id,
      'username', coalesce(nullif(trim(p.username), ''), 'Traveler'),
      'diamonds', p.diamonds,
      'games_won', coalesce(p.games_won, 0),
      'rank_points', coalesce(p.rank_points, 0),
      'hardcore_points', coalesce(p.hardcore_points, 0)
    )
    into v_local
    from public.profiles p
    where p.id = v_uid;
  end if;

  return json_build_object(
    'top', v_top,
    'local', v_local,
    'local_in_top', v_in_top,
    'sort', v_sort
  );
end;
$$;

revoke all on function public.get_global_leaderboard(int, text) from public, anon;
grant execute on function public.get_global_leaderboard(int, text) to authenticated;

notify pgrst, 'reload schema';
