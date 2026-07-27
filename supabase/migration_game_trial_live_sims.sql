-- =============================================================================
-- Quasar.io — Oyun Deneme (Game Trial): sim oyuncular canlı Hardcore'a girer
-- Amaç: gerçek evrende HC puanı biriktirmek (load-test / Arena Test değil).
-- SQL Editor'da çalıştırın. Safe to re-run.
-- =============================================================================

-- 1) Sim: Hardcore kapılarını aç (kupa + cooldown)
create or replace function public.sim_prepare_live_hardcore()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_meta jsonb;
  v_ok boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select u.email, u.raw_user_meta_data
  into v_email, v_meta
  from auth.users u
  where u.id = v_uid;

  if not found then
    raise exception 'not authenticated';
  end if;

  v_ok :=
    coalesce(v_meta->>'is_sim', '') = 'true'
    or coalesce(v_email, '') like 'sim.%@quasar.sim.local'
    or coalesce(v_email, '') like 'sim.%@example.com';

  if not v_ok then
    raise exception 'forbidden';
  end if;

  begin
    perform public._allow_trusted_profile_write();
  exception when undefined_function then
    null;
  end;

  update public.profiles
  set
    trophy_wins_simple = greatest(coalesce(trophy_wins_simple, 0), 1),
    trophy_wins_normal = greatest(coalesce(trophy_wins_normal, 0), 3),
    trophy_wins_elite = greatest(coalesce(trophy_wins_elite, 0), 3),
    trophy_wins_unique = greatest(coalesce(trophy_wins_unique, 0), 3),
    hardcore_cooldown_until = null,
    diamonds = greatest(coalesce(diamonds, 0), 500),
    games_won = greatest(coalesce(games_won, 0), 1),
    updated_at = timezone('utc', now())
  where id = v_uid;

  if not found then
    insert into public.profiles (
      id, username, diamonds, games_won, active_skin,
      trophy_wins_simple, trophy_wins_normal, trophy_wins_elite, trophy_wins_unique,
      hardcore_cooldown_until, updated_at
    ) values (
      v_uid,
      left('S' || substr(replace(v_uid::text, '-', ''), 1, 11), 12),
      500, 1, 'default',
      1, 3, 3, 3,
      null, timezone('utc', now())
    );
  end if;

  return json_build_object(
    'ok', true,
    'user_id', v_uid,
    'hardcore_ready', true
  );
end;
$$;

revoke all on function public.sim_prepare_live_hardcore() from public, anon;
grant execute on function public.sim_prepare_live_hardcore() to authenticated;

comment on function public.sim_prepare_live_hardcore() is
  'Sim only: unlock live Hardcore (10 trophies) and clear entry cooldown for game-trial grind.';

-- 2) join_hardcore_universe — sim oyuncular kupa/cooldown atlar (canlı singleton)
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

  -- Admin + sim: no trophy / cooldown / tutorial gates.
  if not v_is_admin and not v_is_sim then
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
  elsif v_is_sim then
    -- Clear any leftover cooldown so grind loops never stall.
    begin
      perform public._allow_trusted_profile_write();
    exception when undefined_function then
      null;
    end;
    update public.profiles
    set hardcore_cooldown_until = null
    where id = v_user_id
      and hardcore_cooldown_until is not null;
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

  -- Admin: seat-exempt spectator path (does not consume cap).
  if v_is_admin and not v_is_sim then
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

-- 3) Admin: aktif deneme sim'lerinin HC puan sıralaması
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

  select coalesce(json_agg(row_to_json(t) order by t.hardcore_points desc, t.username), '[]'::json)
  into v_rows
  from (
    select
      p.id as user_id,
      p.username,
      coalesce(p.hardcore_points, 0) as hardcore_points,
      coalesce(p.games_won, 0) as games_won,
      coalesce(p.diamonds, 0) as diamonds,
      (
        select count(*) > 0
        from public.game_room_members grm
        join public.game_room_instances gri on gri.id = grm.room_instance_id
        where grm.user_id = p.id
          and gri.room_type = 'hardcore'
          and coalesce(gri.is_load_test, false) = false
      ) as in_hardcore,
      exists (
        select 1 from public.hardcore_queue hq where hq.user_id = p.id
      ) as queued
    from public.profiles p
    where (
      p_user_ids is not null and p.id = any(p_user_ids)
    ) or (
      p_user_ids is null
      and exists (
        select 1 from auth.users u
        where u.id = p.id
          and (
            coalesce(u.raw_user_meta_data->>'is_sim', '') = 'true'
            or coalesce(u.email, '') like 'sim.%@quasar.sim.local'
            or coalesce(u.email, '') like 'sim.%@example.com'
          )
      )
      and coalesce(p.hardcore_points, 0) > 0
    )
    order by coalesce(p.hardcore_points, 0) desc, p.username
    limit 100
  ) t;

  return json_build_object(
    'rankings', coalesce(v_rows, '[]'::json),
    'fetched_at', timezone('utc', now())
  );
end;
$$;

revoke all on function public.get_admin_game_trial_rankings(uuid[]) from public, anon;
grant execute on function public.get_admin_game_trial_rankings(uuid[]) to authenticated;

-- 4) Sim: canlı Hardcore zaferi → +1 HC puan (apply_match_result'a bağımlı değil)
create or replace function public.sim_claim_hardcore_victory(
  p_room_instance_id uuid default null
)
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_meta jsonb;
  v_ok boolean := false;
  v_pts int := 0;
  v_diamonds int := 0;
  v_reward int := 40;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select u.email, u.raw_user_meta_data
  into v_email, v_meta
  from auth.users u
  where u.id = v_uid;

  if not found then
    raise exception 'not authenticated';
  end if;

  v_ok :=
    coalesce(v_meta->>'is_sim', '') = 'true'
    or coalesce(v_email, '') like 'sim.%@quasar.sim.local'
    or coalesce(v_email, '') like 'sim.%@example.com';

  if not v_ok then
    raise exception 'forbidden';
  end if;

  begin
    perform public._allow_trusted_profile_write();
  exception when undefined_function then
    null;
  end;

  begin
    select coalesce(
      (public.get_app_economy_config() ->> 'hardcore_victory_diamonds')::int,
      40
    )
    into v_reward;
  exception when others then
    v_reward := 40;
  end;

  update public.profiles
  set
    hardcore_points = coalesce(hardcore_points, 0) + 1,
    games_won = coalesce(games_won, 0) + 1,
    diamonds = coalesce(diamonds, 0) + greatest(0, v_reward),
    hardcore_cooldown_until = null,
    updated_at = timezone('utc', now())
  where id = v_uid
  returning hardcore_points, diamonds into v_pts, v_diamonds;

  if p_room_instance_id is not null then
    begin
      perform public.hardcore_release_member(p_room_instance_id, v_uid);
    exception when others then
      begin
        perform public.leave_game_room(p_room_instance_id);
      exception when others then
        null;
      end;
    end;
  end if;

  return json_build_object(
    'ok', true,
    'hardcore_points', coalesce(v_pts, 0),
    'diamonds', coalesce(v_diamonds, 0),
    'reward_diamonds', greatest(0, v_reward)
  );
end;
$$;

revoke all on function public.sim_claim_hardcore_victory(uuid) from public, anon;
grant execute on function public.sim_claim_hardcore_victory(uuid) to authenticated;

comment on function public.sim_claim_hardcore_victory(uuid) is
  'Sim only: award +1 hardcore_points on live Hardcore win and clear cooldown for grind loop.';
