-- App economy config: diamond rewards, elim penalties, unlocks, chest, caps.
-- Defaults bump elim: Normal −2, Elite −3, Unique −4 (Training 0).
-- Run after migration_training_wins_excluded.sql + daily chest v4 + round3 fixes.

-- -----------------------------------------------------------------------------
-- 1) Table
-- -----------------------------------------------------------------------------

create table if not exists public.app_economy_config (
  id int primary key default 1 check (id = 1),
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.app_economy_config (id, config) values
  (1, jsonb_build_object(
    'v', 1,
    'rewardSimple1', 3,
    'rewardSimple2', 2,
    'rewardSimple3', 1,
    'rewardNormal1', 5,
    'rewardNormal2', 3,
    'rewardNormal3', 2,
    'rewardElite1', 10,
    'rewardElite2', 6,
    'rewardElite3', 4,
    'rewardUnique1', 15,
    'rewardUnique2', 10,
    'rewardUnique3', 5,
    'penaltySimple', 0,
    'penaltyNormal', 2,
    'penaltyElite', 3,
    'penaltyUnique', 4,
    'unlockNormal', 25,
    'unlockElite', 100,
    'unlockUnique', 200,
    'dailyMatchDiamondCap', 120,
    'chestAmount1', 5,
    'chestAmount2', 10,
    'chestAmount3', 15,
    'rewardClaimsPerDay', 25,
    'trainingClaimsPerDay', 8,
    'adDoublesPerDay', 3
  ))
on conflict (id) do update
set
  config = excluded.config,
  updated_at = timezone('utc', now())
where public.app_economy_config.config is null
   or public.app_economy_config.config = '{}'::jsonb
   or not (public.app_economy_config.config ? 'penaltyNormal');

-- If row exists with old empty / missing penalty keys, merge new defaults for penalties only
update public.app_economy_config
set
  config = config
    || jsonb_build_object(
      'penaltyNormal', coalesce((config ->> 'penaltyNormal')::int, 2),
      'penaltyElite', coalesce((config ->> 'penaltyElite')::int, 3),
      'penaltyUnique', coalesce((config ->> 'penaltyUnique')::int, 4)
    ),
  updated_at = timezone('utc', now())
where id = 1
  and (
    not (config ? 'penaltyNormal')
    or (config ->> 'penaltyNormal')::int = 1
  );

alter table public.app_economy_config enable row level security;

drop policy if exists "app_economy_config_select_authenticated" on public.app_economy_config;
create policy "app_economy_config_select_authenticated"
  on public.app_economy_config
  for select
  to authenticated
  using (true);

drop policy if exists "app_economy_config_upsert_admin" on public.app_economy_config;
create policy "app_economy_config_upsert_admin"
  on public.app_economy_config
  for all
  to authenticated
  using (public._is_admin_user(auth.uid()))
  with check (public._is_admin_user(auth.uid()));

-- -----------------------------------------------------------------------------
-- 2) Helpers
-- -----------------------------------------------------------------------------

create or replace function public._economy_cfg_int(p_key text, p_default int)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cfg jsonb;
  v_val int;
begin
  select config into v_cfg
  from public.app_economy_config
  where id = 1;

  if v_cfg is null or not (v_cfg ? p_key) then
    return p_default;
  end if;

  begin
    v_val := (v_cfg ->> p_key)::int;
  exception
    when others then
      return p_default;
  end;

  if v_val is null then
    return p_default;
  end if;

  return v_val;
end;
$$;

revoke all on function public._economy_cfg_int(text, int)
  from public, anon, authenticated;

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

revoke all on function public._economy_placement_delta(text, int)
  from public, anon, authenticated;

-- Returns negative delta (or 0).
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

revoke all on function public._economy_elimination_delta(text)
  from public, anon, authenticated;

create or replace function public._economy_unlock_required(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
begin
  return case v_room
    when 'simple' then 0
    when 'elite' then greatest(0, public._economy_cfg_int('unlockElite', 100))
    when 'unique' then greatest(0, public._economy_cfg_int('unlockUnique', 200))
    else greatest(0, public._economy_cfg_int('unlockNormal', 25))
  end;
end;
$$;

revoke all on function public._economy_unlock_required(text)
  from public, anon, authenticated;

create or replace function public._economy_chest_base_pick()
returns int
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_a int := greatest(1, public._economy_cfg_int('chestAmount1', 5));
  v_b int := greatest(1, public._economy_cfg_int('chestAmount2', 10));
  v_c int := greatest(1, public._economy_cfg_int('chestAmount3', 15));
begin
  return (array[v_a, v_b, v_c])[1 + floor(random() * 3)::int];
end;
$$;

revoke all on function public._economy_chest_base_pick()
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3) apply_match_result — reads economy config
-- -----------------------------------------------------------------------------

create or replace function public.apply_match_result(
  p_room_type text default 'normal',
  p_placement int default null,
  p_eliminated boolean default false,
  p_room_instance_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_delta int := 0;
  v_won int := 0;
  v_rank_delta int := 0;
  v_new_diamonds int;
  v_kind text;
  v_member record;
  v_room_row public.game_room_instances%rowtype;
  v_session public.analytics_play_sessions%rowtype;
  v_reward_count int;
  v_simple_reward_count int;
  v_last_reward_at timestamptz;
  v_day_diamonds int;
  v_min_seconds int := 60;
  v_peak int;
  v_match_gen int;
  v_reward_limit int;
  v_training_limit int;
  v_day_cap int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique', 'hardcore') then
    raise exception 'invalid room_type';
  end if;

  if coalesce(p_eliminated, false) then
    v_kind := 'penalty';
    v_delta := public._economy_elimination_delta(v_room);
  else
    v_kind := 'reward';
    if p_placement is null or p_placement < 1 or p_placement > 3 then
      select diamonds into v_new_diamonds
      from public.profiles
      where id = v_uid;
      return coalesce(v_new_diamonds, 0);
    end if;

    v_delta := public._economy_placement_delta(v_room, p_placement);

    if p_placement = 1 and v_room <> 'simple' then
      v_won := 1;
    elsif p_placement = 1 and v_room = 'simple' then
      v_won := 0;
    end if;

    if v_won = 1 then
      v_rank_delta := public._rank_win_points_for_room(v_room);
    end if;
  end if;

  -- Keep 1st-place path even when diamond/rank deltas are 0 (universe cups).
  if v_delta = 0 and v_won = 0 and v_rank_delta = 0
     and not (v_kind = 'reward' and coalesce(p_placement, 0) = 1) then
    select diamonds into v_new_diamonds
    from public.profiles
    where id = v_uid;
    return coalesce(v_new_diamonds, 0);
  end if;

  if not public._is_admin_user(v_uid) then
    if v_room = 'simple' then
      v_min_seconds := 90;
    end if;

    select *
    into v_session
    from public.analytics_play_sessions s
    where s.user_id = v_uid
      and s.room_type = v_room
      and (
        s.ended_at is null
        or s.ended_at >= timezone('utc', now()) - interval '15 minutes'
      )
      and not exists (
        select 1
        from public.match_reward_claims c
        where c.play_session_id = s.id
      )
    order by s.started_at desc
    limit 1
    for update;

    if not found then
      select *
      into v_session
      from public.analytics_play_sessions
      where user_id = v_uid
        and room_type = v_room
        and (
          ended_at is null
          or ended_at >= timezone('utc', now()) - interval '15 minutes'
        )
      order by started_at desc
      limit 1
      for update;
    end if;

    if not found then
      raise exception 'no_play_session';
    end if;

    if v_session.started_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
      raise exception 'match_too_short';
    end if;

    if v_room = 'simple' then
      if p_room_instance_id is not null then
        raise exception 'training_no_room_instance';
      end if;
      v_match_gen := null;
    else
      if p_room_instance_id is null then
        raise exception 'room_instance_required';
      end if;

      select * into v_room_row
      from public.game_room_instances
      where id = p_room_instance_id
      for update;

      if not found then
        raise exception 'room_not_found';
      end if;

      if lower(v_room_row.room_type) <> v_room then
        raise exception 'room_type_mismatch';
      end if;

      v_match_gen := coalesce(v_room_row.match_generation, 1);

      select *
      into v_member
      from public.game_room_members
      where room_instance_id = p_room_instance_id
        and user_id = v_uid
        and (
          left_at is null
          or left_at >= timezone('utc', now()) - interval '2 hours'
        )
      order by joined_at desc
      limit 1
      for update;

      if not found then
        raise exception 'not_room_member';
      end if;

      if v_member.joined_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
        raise exception 'match_too_short';
      end if;

      v_peak := greatest(
        coalesce(v_room_row.peak_leader_radius, 25),
        coalesce(v_room_row.leader_radius, 25)
      );

      if v_kind = 'reward' and p_placement = 1 then
        if v_room = 'hardcore' then
          if v_peak < 550 then
            raise exception 'victory_not_verified';
          end if;
        elsif v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;

      if v_kind = 'reward' and p_placement in (2, 3) then
        if v_peak < 180 then
          raise exception 'placement_not_verified';
        end if;
      end if;
    end if;

    if v_kind = 'reward' then
      v_reward_limit := greatest(1, public._economy_cfg_int('rewardClaimsPerDay', 25));
      v_training_limit := greatest(1, public._economy_cfg_int('trainingClaimsPerDay', 8));
      v_day_cap := greatest(1, public._economy_cfg_int('dailyMatchDiamondCap', 120));

      select count(*)::int, max(created_at)
      into v_reward_count, v_last_reward_at
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_reward_count, 0) >= v_reward_limit then
        raise exception 'reward_daily_limit';
      end if;

      if v_room = 'simple' then
        select count(*)::int
        into v_simple_reward_count
        from public.match_reward_claims
        where user_id = v_uid
          and claim_kind = 'reward'
          and room_type = 'simple'
          and created_at >= timezone('utc', now()) - interval '24 hours';

        if coalesce(v_simple_reward_count, 0) >= v_training_limit then
          raise exception 'training_daily_limit';
        end if;
      end if;

      if v_last_reward_at is not null
         and v_last_reward_at > timezone('utc', now()) - interval '60 seconds' then
        raise exception 'reward_cooldown';
      end if;

      select coalesce(sum(greatest(diamond_delta, 0)), 0)::int
      into v_day_diamonds
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap then
        raise exception 'diamond_daily_cap';
      end if;
    end if;

    begin
      insert into public.match_reward_claims (
        user_id,
        room_type,
        room_instance_id,
        play_session_id,
        claim_kind,
        placement,
        diamond_delta,
        match_generation
      )
      values (
        v_uid,
        v_room,
        case when v_room = 'simple' then null else p_room_instance_id end,
        v_session.id,
        v_kind,
        case when v_kind = 'penalty' then null else p_placement end,
        v_delta,
        v_match_gen
      );
    exception
      when unique_violation then
        raise exception 'already_claimed';
    end;
  end if;

  perform public._allow_trusted_profile_write();
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config(
    'quasar.analytics_placement',
    case
      when v_kind = 'penalty' then ''
      else coalesce(p_placement::text, '')
    end,
    true
  );
  perform set_config(
    'quasar.analytics_eliminated',
    case when v_kind = 'penalty' then 'true' else 'false' end,
    true
  );

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    games_won = games_won + v_won,
    rank_points = greatest(0, coalesce(rank_points, 0) + v_rank_delta),
    tutorial_completed = coalesce(tutorial_completed, false)
      or (v_room = 'simple' and v_kind = 'reward' and coalesce(p_placement, 0) = 1),
    trophy_wins_simple = case
      when v_room = 'simple' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(1, coalesce(trophy_wins_simple, 0) + 1)
      else trophy_wins_simple
    end,
    trophy_wins_normal = case
      when v_room = 'normal' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_normal, 0) + 1)
      else trophy_wins_normal
    end,
    trophy_wins_elite = case
      when v_room = 'elite' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_elite, 0) + 1)
      else trophy_wins_elite
    end,
    trophy_wins_unique = case
      when v_room = 'unique' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_unique, 0) + 1)
      else trophy_wins_unique
    end,
    hardcore_points = case
      when v_room = 'hardcore' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then coalesce(hardcore_points, 0) + 1
      else hardcore_points
    end,
    hardcore_cooldown_until = case
      when v_room = 'hardcore'
        and not public._is_admin_user(v_uid)
        and (
          (v_kind = 'reward' and coalesce(p_placement, 0) = 1)
          or v_kind = 'penalty'
        ) then timezone('utc', now()) + interval '1 hour'
      else hardcore_cooldown_until
    end,
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

revoke all on function public.apply_match_result(text, int, boolean, uuid) from public;
grant execute on function public.apply_match_result(text, int, boolean, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Join unlocks from economy config (bodies match training_wins_excluded)
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
  v_diamonds int;
  v_required int;
  v_occ int;
  v_cap int := public._max_real_players_per_room();
  v_is_sim boolean := false;
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

  begin
    v_is_sim := public._is_sim_auth_user(v_user_id);
  exception when undefined_function then
    v_is_sim := false;
  end;

  if not v_is_sim and not public._is_admin_user(v_user_id) then
    select diamonds into v_diamonds
    from public.profiles
    where id = v_user_id;

    if public._needs_first_login_lock(v_user_id) then
      raise exception 'first_login_lock';
    end if;

    v_required := public._economy_unlock_required(v_room_type);

    if coalesce(v_diamonds, 0) < v_required then
      raise exception 'insufficient_diamonds';
    end if;
  end if;

  perform public.leave_game_room(null);

  perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

  begin
    perform public._purge_stale_room_occupancy(v_room_type);
  exception when undefined_function then
    null;
  end;

  if v_is_sim then
    select *
    into v_room
    from public.game_room_instances gri
    where gri.room_type = v_room_type
      and gri.status = 'open'
      and gri.leader_radius < 280
      and not public._room_has_humans(gri.id)
      and public._room_occupancy(gri.id) < v_cap
      and public._room_occupancy(gri.id) > 0
    order by public._room_occupancy(gri.id) desc, gri.instance_number asc
    limit 1
    for update;
  else
    begin
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = v_room_type
        and gri.status = 'open'
        and gri.leader_radius < 280
        and not public._room_has_load_test(gri.id)
        and public._room_human_occupancy(gri.id) < v_cap
        and public._room_human_occupancy(gri.id) > 0
      order by public._room_human_occupancy(gri.id) desc, gri.instance_number asc
      limit 1
      for update;
    exception when undefined_function then
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = v_room_type
        and gri.status = 'open'
        and gri.leader_radius < 280
        and public._room_occupancy(gri.id) < v_cap
        and public._room_occupancy(gri.id) > 0
      order by public._room_occupancy(gri.id) desc, gri.instance_number asc
      limit 1
      for update;
    end;
  end if;

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

      begin
        delete from public.load_test_ghosts
        where room_instance_id = v_room.id;
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
      where room_type = v_room_type;

      insert into public.game_room_instances (
        room_type,
        instance_number,
        real_player_count,
        leader_radius,
        peak_leader_radius,
        match_generation,
        status
      )
      values (v_room_type, v_next_instance, 0, 25, 25, 1, 'open')
      returning * into v_room;
    end if;
  end if;

  begin
    if v_is_sim and public._room_has_humans(v_room.id) then
      raise exception 'load_test_room_conflict';
    end if;
    if not v_is_sim and public._room_has_load_test(v_room.id) then
      raise exception 'load_test_room_conflict';
    end if;
  exception when undefined_function then
    null;
  end;

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, v_user_id);

  v_occ := public._sync_room_occupancy(v_room.id);

  select * into v_room from public.game_room_instances where id = v_room.id;

  return json_build_object(
    'room_instance_id', v_room.id,
    'instance_number', v_room.instance_number,
    'real_player_count', coalesce(v_occ, v_room.real_player_count),
    'leader_radius', v_room.leader_radius,
    'room_type', v_room.room_type,
    'match_generation', coalesce(v_room.match_generation, 1)
  );
end;
$$;

revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;

create or replace function public.join_game_room_instance(p_room_instance_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_diamonds int;
  v_required int;
  v_occ int;
  v_cap int := public._max_real_players_per_room();
  v_is_sim boolean := false;
  v_is_admin boolean := false;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if p_room_instance_id is null then
    raise exception 'invalid room_instance';
  end if;

  begin
    perform public._purge_stale_room_occupancy(null);
  exception when undefined_function then
    null;
  end;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found then
    raise exception 'room_not_found';
  end if;

  if v_room.status <> 'open' then
    raise exception 'room_closed';
  end if;

  if v_room.room_type = 'simple' then
    raise exception 'training_room_no_matchmaking';
  end if;

  begin
    v_is_sim := public._is_sim_auth_user(v_user_id);
  exception when undefined_function then
    v_is_sim := false;
  end;
  v_is_admin := public._is_admin_user(v_user_id);

  begin
    if not v_is_sim and not v_is_admin and public._room_has_load_test(v_room.id) then
      raise exception 'load_test_room_forbidden';
    end if;
    if v_is_sim and public._room_has_humans(v_room.id) then
      raise exception 'load_test_room_conflict';
    end if;
  exception when undefined_function then
    null;
  end;

  if not v_is_sim and not v_is_admin then
    select diamonds into v_diamonds
    from public.profiles
    where id = v_user_id;

    if public._needs_first_login_lock(v_user_id) then
      raise exception 'first_login_lock';
    end if;

    v_required := public._economy_unlock_required(v_room.room_type);

    if coalesce(v_diamonds, 0) < v_required then
      raise exception 'insufficient_diamonds';
    end if;
  end if;

  if v_room.leader_radius >= 280 then
    raise exception 'room_ending';
  end if;

  if public._room_occupancy(v_room.id) >= v_cap then
    raise exception 'room_full';
  end if;

  perform public.leave_game_room(null);

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, v_user_id);

  v_occ := public._sync_room_occupancy(v_room.id);

  update public.game_room_instances
  set updated_at = timezone('utc', now())
  where id = v_room.id;

  select * into v_room from public.game_room_instances where id = v_room.id;

  return json_build_object(
    'room_instance_id', v_room.id,
    'instance_number', v_room.instance_number,
    'real_player_count', coalesce(v_occ, v_room.real_player_count),
    'leader_radius', v_room.leader_radius,
    'room_type', v_room.room_type
  );
end;
$$;

revoke all on function public.join_game_room_instance(uuid) from public, anon;
grant execute on function public.join_game_room_instance(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Daily chest amounts from config
-- -----------------------------------------------------------------------------

alter table public.daily_lobby_chest_claims
  drop constraint if exists daily_lobby_chest_claims_diamond_delta_check;

alter table public.daily_lobby_chest_claims
  add constraint daily_lobby_chest_claims_diamond_delta_check
  check (diamond_delta > 0 and diamond_delta <= 1000);

create or replace function public.claim_daily_lobby_chest(
  p_doubled boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
  v_base int;
  v_amount int;
  v_new_diamonds int;
  v_admin boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_admin := public._is_admin_user(v_uid);

  v_base := public._economy_chest_base_pick();
  v_amount := case when coalesce(p_doubled, false) then v_base * 2 else v_base end;

  if v_admin then
    delete from public.daily_lobby_chest_claims
    where user_id = v_uid
      and claim_day = v_day;
  end if;

  begin
    insert into public.daily_lobby_chest_claims (
      user_id, claim_day, diamond_delta, ad_doubled
    )
    values (v_uid, v_day, v_amount, coalesce(p_doubled, false));
  exception
    when unique_violation then
      return jsonb_build_object(
        'ok', false,
        'reason', 'already_claimed',
        'claim_day', v_day,
        'next_available_at',
          ((v_day + 1)::timestamp at time zone 'utc')
      );
  end;

  perform public._allow_trusted_profile_write();

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_amount),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  if v_new_diamonds is null then
    raise exception 'profile_missing';
  end if;

  return jsonb_build_object(
    'ok', true,
    'awarded', v_amount,
    'base_awarded', v_base,
    'doubled', coalesce(p_doubled, false),
    'diamonds', v_new_diamonds,
    'claim_day', v_day,
    'admin_bypass', v_admin
  );
end;
$$;

revoke all on function public.claim_daily_lobby_chest(boolean) from public, anon;
grant execute on function public.claim_daily_lobby_chest(boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) Ad-double daily limit from config
-- -----------------------------------------------------------------------------

create or replace function public.claim_rewarded_match_double(
  p_room_type text default 'normal',
  p_room_instance_id uuid default null,
  p_session_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_room_row public.game_room_instances%rowtype;
  v_claim public.match_reward_claims%rowtype;
  v_match_gen int;
  v_day_count int;
  v_bonus int;
  v_new_diamonds int;
  v_elapsed_prepare double precision;
  v_elapsed_attest double precision;
  v_double_limit int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('normal', 'elite', 'unique') then
    raise exception 'ad_double_not_allowed';
  end if;

  if p_room_instance_id is null then
    raise exception 'room_required';
  end if;

  if p_session_id is null then
    raise exception 'ad_session_required';
  end if;

  select *
  into v_room_row
  from public.game_room_instances
  where id = p_room_instance_id
  for share;

  if not found then
    raise exception 'room_not_found';
  end if;

  if lower(v_room_row.room_type) <> v_room then
    raise exception 'room_type_mismatch';
  end if;

  v_match_gen := coalesce(v_room_row.match_generation, 1);

  select *
  into v_claim
  from public.match_reward_claims
  where user_id = v_uid
    and room_instance_id = p_room_instance_id
    and match_generation = v_match_gen
    and claim_kind = 'reward'
    and diamond_delta > 0
  for update;

  if not found then
    raise exception 'no_reward_claim';
  end if;

  if v_claim.ad_double_claimed_at is not null then
    raise exception 'already_doubled';
  end if;

  if v_claim.ad_double_session_id is distinct from p_session_id then
    raise exception 'ad_session_invalid';
  end if;

  if v_claim.ad_double_prepared_at is null
     or v_claim.ad_double_attested_at is null then
    raise exception 'ad_not_attested';
  end if;

  if not public._ad_double_client_attest_allowed()
     and nullif(trim(coalesce(v_claim.ad_double_ssv_txn, '')), '') is null then
    raise exception 'ssv_required';
  end if;

  v_elapsed_prepare := extract(
    epoch from (timezone('utc', now()) - v_claim.ad_double_prepared_at)
  );
  v_elapsed_attest := extract(
    epoch from (timezone('utc', now()) - v_claim.ad_double_attested_at)
  );

  if v_elapsed_prepare < 15 then
    raise exception 'ad_watch_too_short';
  end if;

  if v_elapsed_attest < 2 then
    raise exception 'ad_watch_too_short';
  end if;

  if v_elapsed_prepare > 300 then
    raise exception 'ad_session_expired';
  end if;

  if v_claim.created_at < timezone('utc', now()) - interval '10 minutes' then
    raise exception 'ad_double_expired';
  end if;

  v_double_limit := greatest(0, public._economy_cfg_int('adDoublesPerDay', 3));

  select count(*)::int
  into v_day_count
  from public.match_reward_claims
  where user_id = v_uid
    and ad_double_claimed_at is not null
    and ad_double_claimed_at >= timezone('utc', now()) - interval '24 hours';

  if coalesce(v_day_count, 0) >= v_double_limit then
    raise exception 'ad_double_daily_limit';
  end if;

  v_bonus := v_claim.diamond_delta;

  update public.match_reward_claims
  set
    ad_double_claimed_at = timezone('utc', now()),
    ad_double_session_id = null,
    ad_double_prepared_at = null,
    ad_double_attested_at = null
  where id = v_claim.id
    and ad_double_claimed_at is null
    and ad_double_session_id = p_session_id
    and ad_double_attested_at is not null;

  if not found then
    raise exception 'already_doubled';
  end if;

  perform public._allow_trusted_profile_write();
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config('quasar.analytics_placement', coalesce(v_claim.placement::text, ''), true);
  perform set_config('quasar.analytics_eliminated', 'false', true);

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_bonus),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

revoke all on function public.claim_rewarded_match_double(text, uuid, uuid)
  from public, anon;
grant execute on function public.claim_rewarded_match_double(text, uuid, uuid)
  to authenticated;

notify pgrst, 'reload schema';
