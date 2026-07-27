-- =============================================================================
-- Quasar.io — Oyun Deneme: gerçek oyuncu kuralları (kupa / elmas / cooldown)
-- Önceki migration_game_trial_live_sims.sql bypass'larını kaldırır.
-- SQL Editor'da çalıştırın. Safe to re-run.
-- =============================================================================

-- 1) Helpers
create or replace function public._is_game_trial_auth_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (
      select coalesce(u.raw_user_meta_data->>'is_game_trial', '') = 'true'
      from auth.users u
      where u.id = p_user_id
    ),
    false
  );
$$;

revoke all on function public._is_game_trial_auth_user(uuid)
  from public, anon, authenticated;

-- Load-test isolation only (Arena / yük testi). Game-trial = gerçek oyuncu.
create or replace function public._is_load_test_sim_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(public._is_sim_auth_user(p_user_id), false)
    and not coalesce(public._is_game_trial_auth_user(p_user_id), false);
$$;

revoke all on function public._is_load_test_sim_user(uuid)
  from public, anon, authenticated;

-- 2) Yeni oyuncu profili (20 elmas, 0 kupa) — ücretsiz kupa/HC yok
create or replace function public.prepare_game_trial_player()
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
  v_name text;
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
    coalesce(v_meta->>'is_game_trial', '') = 'true'
    or (
      coalesce(v_meta->>'is_sim', '') = 'true'
      and (
        coalesce(v_email, '') like 'sim.%@quasar.sim.local'
        or coalesce(v_email, '') like 'sim.%@example.com'
      )
    );

  if not v_ok then
    raise exception 'forbidden';
  end if;

  -- Ensure meta flag for matchmaking
  update auth.users
  set raw_user_meta_data =
    coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('is_sim', true, 'is_game_trial', true)
  where id = v_uid;

  v_name := left(
    coalesce(
      nullif(trim(v_meta->>'full_name'), ''),
      nullif(trim(v_meta->>'name'), ''),
      'Gt' || substr(replace(v_uid::text, '-', ''), 1, 10)
    ),
    12
  );

  begin
    perform public._allow_trusted_profile_write();
  exception when undefined_function then
    null;
  end;

  insert into public.profiles (
    id, username, diamonds, games_won, active_skin,
    trophy_wins_simple, trophy_wins_normal, trophy_wins_elite, trophy_wins_unique,
    hardcore_points, hardcore_cooldown_until, tutorial_completed, updated_at
  ) values (
    v_uid, v_name, 20, 0, 'default',
    0, 0, 0, 0,
    0, null, false, timezone('utc', now())
  )
  on conflict (id) do update
  set
    username = coalesce(nullif(trim(public.profiles.username), ''), excluded.username),
    -- Keep progress if already playing; only bootstrap empty new accounts
    diamonds = case
      when public.profiles.updated_at > timezone('utc', now()) - interval '10 seconds'
        then public.profiles.diamonds
      when coalesce(public.profiles.games_won, 0) = 0
        and coalesce(public.profiles.trophy_wins_normal, 0)
          + coalesce(public.profiles.trophy_wins_elite, 0)
          + coalesce(public.profiles.trophy_wins_unique, 0)
          + coalesce(public.profiles.trophy_wins_simple, 0) = 0
        and coalesce(public.profiles.hardcore_points, 0) = 0
        then 20
      else public.profiles.diamonds
    end,
    updated_at = timezone('utc', now());

  return json_build_object(
    'ok', true,
    'user_id', v_uid,
    'username', v_name,
    'starter', true
  );
end;
$$;

revoke all on function public.prepare_game_trial_player() from public, anon;
grant execute on function public.prepare_game_trial_player() to authenticated;

-- Legacy bypass → no-op redirect (eğitim/kupa vermez)
create or replace function public.sim_prepare_live_hardcore()
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.prepare_game_trial_player();
end;
$$;

-- Bypass zafer claim kapat — gerçek apply_match_result kullanılmalı
create or replace function public.sim_claim_hardcore_victory(
  p_room_instance_id uuid default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'use_apply_match_result'
    using hint = 'Game trial must claim wins via apply_match_result like real players';
end;
$$;

-- 3) Admin mint: game-trial bayrağı
create or replace function public.admin_mark_game_trial_player(p_user_id uuid)
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  perform public._require_admin();
  if p_user_id is null then
    raise exception 'invalid user';
  end if;

  update auth.users
  set raw_user_meta_data =
    coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('is_sim', true, 'is_game_trial', true)
  where id = p_user_id;

  begin
    perform public._allow_trusted_profile_write();
  exception when undefined_function then
    null;
  end;

  update public.profiles
  set
    diamonds = 20,
    games_won = 0,
    trophy_wins_simple = 0,
    trophy_wins_normal = 0,
    trophy_wins_elite = 0,
    trophy_wins_unique = 0,
    hardcore_points = 0,
    hardcore_cooldown_until = null,
    tutorial_completed = false,
    updated_at = timezone('utc', now())
  where id = p_user_id;

  return json_build_object('ok', true, 'user_id', p_user_id);
end;
$$;

revoke all on function public.admin_mark_game_trial_player(uuid) from public, anon;
grant execute on function public.admin_mark_game_trial_player(uuid) to authenticated;

-- 4) join_hardcore_universe — yalnız admin muaf; sim/game-trial = gerçek kurallar
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

-- 5) join_game_room — game-trial gerçek oda + elmas kapısı (load-test izolasyonu yok)
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
  v_is_load_test_sim boolean := false;
  v_is_game_trial boolean := false;
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
    v_is_load_test_sim := public._is_load_test_sim_user(v_user_id);
  exception when undefined_function then
    begin
      v_is_load_test_sim := public._is_sim_auth_user(v_user_id);
    exception when undefined_function then
      v_is_load_test_sim := false;
    end;
  end;

  begin
    v_is_game_trial := public._is_game_trial_auth_user(v_user_id);
  exception when undefined_function then
    v_is_game_trial := false;
  end;

  -- Game-trial + gerçek oyuncu: elmas / eğitim kilidi
  if not v_is_load_test_sim and not public._is_admin_user(v_user_id) then
    select diamonds into v_diamonds
    from public.profiles
    where id = v_user_id;

    if public._needs_first_login_lock(v_user_id) then
      raise exception 'first_login_lock';
    end if;

    begin
      v_required := public._economy_unlock_required(v_room_type);
    exception when undefined_function then
      v_required := case v_room_type
        when 'normal' then 25
        when 'elite' then 100
        when 'unique' then 200
        else 0
      end;
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

  if v_is_load_test_sim then
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
      and (
        v_is_load_test_sim
        or coalesce(is_load_test, false) = false
      )
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
        is_load_test = v_is_load_test_sim,
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
        status,
        is_load_test
      )
      values (
        v_room_type,
        v_next_instance,
        0,
        25,
        25,
        1,
        'open',
        v_is_load_test_sim
      )
      returning * into v_room;
    end if;
  end if;

  begin
    if v_is_load_test_sim and public._room_has_humans(v_room.id) then
      raise exception 'load_test_room_conflict';
    end if;
    if not v_is_load_test_sim and public._room_has_load_test(v_room.id) then
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
    'is_load_test', coalesce(v_room.is_load_test, false),
    'match_generation', coalesce(v_room.match_generation, 1)
  );
end;
$$;

revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;

comment on function public.prepare_game_trial_player() is
  'Game trial: bootstrap as new player (20 diamonds, 0 trophies). No free Hardcore unlock.';
comment on function public.join_hardcore_universe() is
  'Live Hardcore join — trophy + cooldown gates for everyone except admin.';

-- 6) Ensure apply_match_result accepts hardcore (real HC points + cooldown)
do $$
declare
  v_def text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    return;
  end;

  if position('''hardcore''' in v_def) = 0
     and position('hardcore' in v_def) = 0 then
    v_def := replace(
      v_def,
      'if v_room not in (''simple'', ''normal'', ''elite'', ''unique'') then',
      'if v_room not in (''simple'', ''normal'', ''elite'', ''unique'', ''hardcore'') then'
    );
  end if;

  if position('hardcore_points' in v_def) = 0 then
    v_def := replace(
      v_def,
      'updated_at = timezone(''utc'', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;',
      'hardcore_points = case
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

  begin
    execute v_def;
  exception when others then
    raise notice 'apply_match_result hardcore ensure failed: %', sqlerrm;
  end;
end $$;
