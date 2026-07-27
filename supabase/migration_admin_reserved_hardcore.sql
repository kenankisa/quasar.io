-- =============================================================================
-- Quasar.io — Admin reserved name + Hardcore unrestricted entry + top rank
-- Run once in Supabase SQL Editor (after migration_hardcore_rules_v2.sql).
-- =============================================================================

-- 1) Reserved username "Admin" — only admin accounts may claim it
create or replace function public.update_player_profile(
  p_username text,
  p_avatar_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_trimmed text;
  v_avatar text;
  v_is_admin boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_trimmed := trim(p_username);

  if char_length(v_trimmed) < 3 or char_length(v_trimmed) > 12 then
    raise exception 'invalid_username_length';
  end if;

  begin
    v_is_admin := public._is_admin_user(v_uid);
  exception when undefined_function then
    v_is_admin := false;
  end;

  -- Exact reserved handle (case-insensitive)
  if lower(v_trimmed) = 'admin' and not v_is_admin then
    raise exception 'username_reserved';
  end if;

  if exists (
    select 1 from public.profiles
    where lower(trim(username)) = lower(v_trimmed)
      and id <> v_uid
  ) then
    raise exception 'username_taken';
  end if;

  if p_avatar_url is not null then
    v_avatar := trim(p_avatar_url);
    if v_avatar !~ (
      '^https://[a-z0-9.-]+/storage/v1/object/public/avatars/'
      || v_uid::text
      || '/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$'
    ) then
      raise exception 'invalid_avatar_url';
    end if;
  end if;

  update public.profiles
  set
    username = v_trimmed,
    avatar_url = coalesce(v_avatar, avatar_url),
    updated_at = timezone('utc', now())
  where id = v_uid;

  update public.leaderboard
  set username = v_trimmed, updated_at = timezone('utc', now())
  where user_id = v_uid;
end;
$$;

revoke all on function public.update_player_profile(text, text) from public;
grant execute on function public.update_player_profile(text, text) to authenticated;

-- Strip non-admin profiles that already hold "Admin"
update public.profiles p
set
  username = 'Player' || substr(replace(p.id::text, '-', ''), 1, 6),
  updated_at = timezone('utc', now())
where lower(trim(p.username)) = 'admin'
  and not coalesce(public._is_admin_user(p.id), false);

-- 2) join_hardcore_universe — admin: no trophy / cooldown / tutorial / queue
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

  -- Seat search: admin ignores leader_radius gate
  begin
    if v_is_admin then
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = 'hardcore'
        and gri.status = 'open'
        and not public._room_has_load_test(gri.id)
        and public._room_human_occupancy(gri.id) < v_cap
      order by public._room_human_occupancy(gri.id) desc, gri.instance_number asc
      limit 1
      for update;
    else
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
    end if;
  exception when undefined_function then
    if v_is_admin then
      select *
      into v_room
      from public.game_room_instances gri
      where gri.room_type = 'hardcore'
        and gri.status = 'open'
        and public._room_occupancy(gri.id) < v_cap
      order by public._room_occupancy(gri.id) desc, gri.instance_number asc
      limit 1
      for update;
    else
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
    end if;
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

  -- Non-admin: queue when an open under-threshold room exists but is full
  if not v_is_admin and exists (
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

  -- Open / create a room (admin always lands here instead of queueing)
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

-- 3) Admin should not receive hardcore cooldown on win/elim
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

  if position('hardcore_cooldown_until = case' in v_def) > 0
     and position('not public._is_admin_user(v_uid)' in v_def) = 0 then
    v_def := replace(
      v_def,
      'hardcore_cooldown_until = case
      when v_room = ''hardcore'' and (
        (v_kind = ''reward'' and coalesce(p_placement, 0) = 1)
        or v_kind = ''penalty''
      ) then timezone(''utc'', now()) + interval ''1 hour''
      else hardcore_cooldown_until
    end,',
      'hardcore_cooldown_until = case
      when v_room = ''hardcore''
        and not public._is_admin_user(v_uid)
        and (
          (v_kind = ''reward'' and coalesce(p_placement, 0) = 1)
          or v_kind = ''penalty''
        ) then timezone(''utc'', now()) + interval ''1 hour''
      else hardcore_cooldown_until
    end,'
    );
    begin
      execute v_def;
    exception when others then
      raise notice 'apply_match_result admin cooldown skip failed: %', sqlerrm;
    end;
  end if;
end $$;

notify pgrst, 'reload schema';
