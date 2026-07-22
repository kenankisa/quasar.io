-- =============================================================================
-- Quasar.io — Eğitim galibiyeti games_won'a eklenmez
-- Kilidi açmak için profiles.tutorial_completed kullanılır.
-- SQL Editor'da çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) tutorial_completed
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists tutorial_completed boolean not null default false;

-- Eski hesaplar: daha önce galibiyet sayılmışsa veya eğitim 1.’liği claim edilmişse aç.
update public.profiles p
set tutorial_completed = true
where coalesce(p.tutorial_completed, false) = false
  and (
    coalesce(p.games_won, 0) > 0
    or exists (
      select 1
      from public.match_reward_claims c
      where c.user_id = p.id
        and c.room_type = 'simple'
        and c.claim_kind = 'reward'
        and c.placement = 1
    )
  );

-- -----------------------------------------------------------------------------
-- 2) first-login kilidi yardımcısı
-- -----------------------------------------------------------------------------

create or replace function public._needs_first_login_lock(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not coalesce(
    (select tutorial_completed from public.profiles where id = p_uid),
    false
  );
$$;

revoke all on function public._needs_first_login_lock(uuid) from public, anon;
grant execute on function public._needs_first_login_lock(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) apply_match_result — simple 1.’likte v_won = 0 + tutorial_completed
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
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if coalesce(p_eliminated, false) then
    v_kind := 'penalty';
    v_delta := case v_room
      when 'simple' then 0
      when 'elite' then -2
      when 'unique' then -3
      else -1
    end;
  else
    v_kind := 'reward';
    if p_placement is null or p_placement < 1 or p_placement > 3 then
      select diamonds into v_new_diamonds
      from public.profiles
      where id = v_uid;
      return coalesce(v_new_diamonds, 0);
    end if;

    case v_room
      when 'simple' then
        if p_placement = 1 then
          v_delta := 3;
          v_won := 0;
        elsif p_placement = 2 then
          v_delta := 2;
        elsif p_placement = 3 then
          v_delta := 1;
        end if;
      when 'elite' then
        if p_placement = 1 then
          v_delta := 10;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 6;
        elsif p_placement = 3 then
          v_delta := 4;
        end if;
      when 'unique' then
        if p_placement = 1 then
          v_delta := 15;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 10;
        elsif p_placement = 3 then
          v_delta := 5;
        end if;
      else
        if p_placement = 1 then
          v_delta := 5;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 3;
        elsif p_placement = 3 then
          v_delta := 2;
        end if;
    end case;

    if v_won = 1 then
      v_rank_delta := public._rank_win_points_for_room(v_room);
    end if;
  end if;

  if v_delta = 0 and v_won = 0 and v_rank_delta = 0
     and not (v_room = 'simple' and v_kind = 'reward' and coalesce(p_placement, 0) = 1) then
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
        if v_peak < 350 then
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
      select count(*)::int, max(created_at)
      into v_reward_count, v_last_reward_at
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_reward_count, 0) >= 25 then
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

        if coalesce(v_simple_reward_count, 0) >= 8 then
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

      if coalesce(v_day_diamonds, 0) + v_delta > 120 then
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
-- 4) join kilitleri — games_won yerine tutorial_completed
-- (load_test_isolation + occupancy reaper ile uyumlu gövde)
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

    v_required := case v_room.room_type
      when 'normal' then 25
      when 'elite' then 100
      when 'unique' then 200
      else 0
    end;

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

notify pgrst, 'reload schema';
