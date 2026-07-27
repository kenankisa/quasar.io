-- Per-member live radius for admin ops (game trial + live Hardcore panels).

alter table public.game_room_members
  add column if not exists current_radius double precision;

comment on column public.game_room_members.current_radius is
  'Last synced player radius while seated (updated via update_room_leader_radius).';

create or replace function public.update_room_leader_radius(
  p_room_instance_id uuid,
  p_leader_radius int,
  p_self_radius int default null
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
  v_is_game_trial boolean := false;
  v_step int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  begin
    v_is_game_trial := coalesce(public._is_game_trial_auth_user(v_uid), false);
  exception when undefined_function then
    v_is_game_trial := false;
  end;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found or v_room.status <> 'open' then
    return;
  end if;

  if lower(v_room.room_type) = 'hardcore' then
    v_hard_cap := case when v_is_game_trial then 600 else 900 end;
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

  if p_self_radius is not null then
    if p_self_radius < 0 or p_self_radius > v_hard_cap then
      raise exception 'invalid self_radius';
    end if;
    update public.game_room_members
    set current_radius = p_self_radius::double precision
    where room_instance_id = p_room_instance_id
      and user_id = v_uid
      and left_at is null;
  end if;

  if v_is_game_trial then
    v_new := least(
      v_hard_cap,
      greatest(
        p_leader_radius,
        least(coalesce(v_room.leader_radius, 0), v_hard_cap)
      )
    );
    if v_new = coalesce(v_room.leader_radius, 0) then
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
    return;
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

  if lower(v_room.room_type) = 'hardcore' then
    v_time_cap := v_hard_cap;
    v_step := 200;
  else
    v_time_cap := least(
      v_hard_cap,
      25 + floor(v_elapsed_sec * 1.8)::int
    );
    v_step := 50;
  end if;

  v_new := least(
    v_time_cap,
    v_hard_cap,
    greatest(
      v_room.leader_radius,
      least(p_leader_radius, v_room.leader_radius + v_step)
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

revoke all on function public.update_room_leader_radius(uuid, int, int)
  from public, anon;
grant execute on function public.update_room_leader_radius(uuid, int, int)
  to authenticated;

-- Live Hardcore admin: include per-player radius.
create or replace function public.get_admin_hardcore_live_ops()
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
  v_won_today int := 0;
  v_lost_today int := 0;
  v_won_hour int := 0;
  v_lost_hour int := 0;
  v_day_start timestamptz := date_trunc('day', timezone('utc', now()));
  v_hour_start timestamptz := timezone('utc', now()) - interval '1 hour';
begin
  perform public._require_admin();
  perform public._ensure_hardcore_singleton();

  select *
  into v_room
  from public.game_room_instances
  where room_type = 'hardcore'
    and coalesce(is_load_test, false) = false
  order by instance_number asc
  limit 1;

  begin
    v_max := greatest(1, public._hardcore_max_players());
  exception
    when others then
      v_max := 20;
  end;

  if v_room.id is not null then
    begin
      v_seats := public._room_hardcore_seat_occupancy(v_room.id);
    exception
      when others then
        v_seats := coalesce(v_room.real_player_count, 0);
    end;

    select coalesce(json_agg(row_to_json(t) order by t.joined_at asc), '[]'::json)
    into v_players
    from (
      select
        grm.user_id::text as user_id,
        coalesce(nullif(trim(p.username), ''), '—') as username,
        grm.joined_at,
        coalesce(public._is_admin_user(grm.user_id), false) as is_admin,
        round(coalesce(grm.current_radius, 0))::int as current_radius
      from public.game_room_members grm
      join public.profiles p on p.id = grm.user_id
      where grm.room_instance_id = v_room.id
        and grm.left_at is null
      order by grm.joined_at asc
    ) t;
  end if;

  select count(*)::int
  into v_queue_count
  from public.hardcore_queue
  where admitted_room_id is null;

  select coalesce(json_agg(row_to_json(t) order by t.position asc), '[]'::json)
  into v_queue
  from (
    select
      row_number() over (order by q.enqueued_at asc)::int as position,
      q.user_id::text as user_id,
      coalesce(nullif(trim(p.username), ''), '—') as username,
      q.enqueued_at
    from public.hardcore_queue q
    join public.profiles p on p.id = q.user_id
    where q.admitted_room_id is null
    order by q.enqueued_at asc
    limit 40
  ) t;

  select
    coalesce(sum(case when d.delta > 0 then d.delta else 0 end), 0)::int,
    coalesce(sum(case when d.delta < 0 then -d.delta else 0 end), 0)::int
  into v_won_today, v_lost_today
  from (
    select diamond_delta as delta, created_at
    from public.hardcore_kill_claims
    where created_at >= v_day_start
    union all
    select diamond_delta as delta, created_at
    from public.match_reward_claims
    where lower(room_type) = 'hardcore'
      and created_at >= v_day_start
  ) d;

  select
    coalesce(sum(case when d.delta > 0 then d.delta else 0 end), 0)::int,
    coalesce(sum(case when d.delta < 0 then -d.delta else 0 end), 0)::int
  into v_won_hour, v_lost_hour
  from (
    select diamond_delta as delta, created_at
    from public.hardcore_kill_claims
    where created_at >= v_hour_start
    union all
    select diamond_delta as delta, created_at
    from public.match_reward_claims
    where lower(room_type) = 'hardcore'
      and created_at >= v_hour_start
  ) d;

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
    'diamonds_won_today', coalesce(v_won_today, 0),
    'diamonds_lost_today', coalesce(v_lost_today, 0),
    'diamonds_won_hour', coalesce(v_won_hour, 0),
    'diamonds_lost_hour', coalesce(v_lost_hour, 0),
    'fetched_at', timezone('utc', now())
  );
end;
$$;

-- Game trial rankings: include live radius when seated.
create or replace function public.get_admin_game_trial_rankings(
  p_user_ids uuid[] default null
)
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_rows json;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if not public._is_admin_user(v_uid) then
    raise exception 'forbidden';
  end if;

  select coalesce(
    json_agg(row_to_json(t) order by t.hardcore_points desc, t.trophies desc, t.diamonds desc, t.username),
    '[]'::json
  )
  into v_rows
  from (
    select
      p.id as user_id,
      p.username,
      coalesce(p.hardcore_points, 0) as hardcore_points,
      coalesce(p.games_won, 0) as games_won,
      coalesce(p.diamonds, 0) as diamonds,
      (
        coalesce(p.trophy_wins_simple, 0)
        + coalesce(p.trophy_wins_normal, 0)
        + coalesce(p.trophy_wins_elite, 0)
        + coalesce(p.trophy_wins_unique, 0)
      ) as trophies,
      (
        select count(*) > 0
        from public.game_room_members grm
        join public.game_room_instances gri on gri.id = grm.room_instance_id
        where grm.user_id = p.id
          and gri.room_type = 'hardcore'
          and coalesce(gri.is_load_test, false) = false
          and grm.left_at is null
      ) as in_hardcore,
      exists (
        select 1 from public.hardcore_queue hq where hq.user_id = p.id
      ) as queued,
      (
        select round(coalesce(grm.current_radius, 0))::int
        from public.game_room_members grm
        where grm.user_id = p.id
          and grm.left_at is null
        order by grm.joined_at desc
        limit 1
      ) as current_radius,
      (
        select count(*) > 0
        from public.game_room_members grm
        where grm.user_id = p.id
          and grm.left_at is null
      ) as in_room
    from public.profiles p
    where (
      p_user_ids is not null and p.id = any(p_user_ids)
    ) or (
      p_user_ids is null
      and exists (
        select 1 from auth.users u
        where u.id = p.id
          and coalesce(u.raw_user_meta_data->>'is_game_trial', '') = 'true'
      )
    )
    order by
      coalesce(p.hardcore_points, 0) desc,
      (
        coalesce(p.trophy_wins_simple, 0)
        + coalesce(p.trophy_wins_normal, 0)
        + coalesce(p.trophy_wins_elite, 0)
        + coalesce(p.trophy_wins_unique, 0)
      ) desc,
      coalesce(p.diamonds, 0) desc,
      p.username
    limit 100
  ) t;

  return json_build_object(
    'rankings', coalesce(v_rows, '[]'::json),
    'fetched_at', timezone('utc', now())
  );
end;
$$;

-- Arena test ops: include per-player radius from members table.
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
      coalesce(public._is_sim_auth_user(grm.user_id), false) as is_sim,
      round(coalesce(grm.current_radius, 0))::int as current_radius
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
    'seat_occupancy', coalesce(v_seats, 0),
    'max_players', v_max,
    'queue_count', coalesce(v_queue_count, 0),
    'players', coalesce(v_players, '[]'::json),
    'queue', coalesce(v_queue, '[]'::json),
    'victory_radius', v_victory_radius,
    'victory_min_alive', v_min_alive,
    'victory_stable_seconds', v_stable,
    'victory_min_pvp_mass_fraction', v_pvp,
    'spawn_protection_seconds', v_spawn,
    'low_pop_radius_cap', v_low_pop_cap,
    'late_food_softcap_radius', v_late_food_r,
    'late_food_softcap_multiplier', v_late_food_m,
    'fetched_at', timezone('utc', now())
  );
end;
$$;

notify pgrst, 'reload schema';
