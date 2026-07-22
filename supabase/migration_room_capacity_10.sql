-- =============================================================================
-- Quasar.io — Rekabetçi odalar: max 10 gerçek oyuncu (10 bot client-side)
-- Eğitim (simple) matchmaking kullanmaz; bu migration onu değiştirmez.
--
-- SQL Editor'da migration_load_test_join_sim_room.sql sonrası çalıştırın.
-- =============================================================================

alter table public.game_room_instances
  add column if not exists match_generation int not null default 1;

create or replace function public._max_real_players_per_room()
returns int
language sql
immutable
as $$
  select 10;
$$;

revoke all on function public._max_real_players_per_room() from public, anon, authenticated;

-- Mevcut sayaçları yeni tavana indir (constraint öncesi)
update public.game_room_instances
set real_player_count = least(real_player_count, public._max_real_players_per_room())
where real_player_count > public._max_real_players_per_room();

alter table public.game_room_instances
  drop constraint if exists game_room_instances_player_count_check;

alter table public.game_room_instances
  add constraint game_room_instances_player_count_check
  check (
    real_player_count >= 0
    and real_player_count <= 10
  );

create or replace function public._sync_room_occupancy(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_cap int := public._max_real_players_per_room();
begin
  v_count := public._room_occupancy(p_room_id);
  update public.game_room_instances
  set
    real_player_count = least(v_cap, greatest(0, v_count)),
    updated_at = timezone('utc', now())
  where id = p_room_id;
  return least(v_cap, greatest(0, v_count));
end;
$$;

revoke all on function public._sync_room_occupancy(uuid) from public, anon, authenticated;

-- Belirli oda instance'ına katıl (sim / yük testi)
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
  v_games_won int;
  v_required int;
  v_occ int;
  v_cap int := public._max_real_players_per_room();
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if p_room_instance_id is null then
    raise exception 'invalid room_instance';
  end if;

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

  if not public._is_admin_user(v_user_id) then
    select diamonds, games_won
    into v_diamonds, v_games_won
    from public.profiles
    where id = v_user_id;

    if coalesce(v_games_won, 0) = 0 then
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

  if v_room.leader_radius >= 250 then
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

-- join_game_room: max 10 gerçek oyuncu; eğitim hariç
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
  v_stale_before timestamptz := timezone('utc', now()) - interval '3 minutes';
  v_diamonds int;
  v_games_won int;
  v_required int;
  v_occ int;
  v_cap int := public._max_real_players_per_room();
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

  if not public._is_admin_user(v_user_id) then
    select diamonds, games_won
    into v_diamonds, v_games_won
    from public.profiles
    where id = v_user_id;

    if coalesce(v_games_won, 0) = 0 then
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

  update public.game_room_members grm
  set left_at = timezone('utc', now())
  from public.game_room_instances gri
  where grm.room_instance_id = gri.id
    and gri.room_type = v_room_type
    and grm.left_at is null
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before
    and not exists (
      select 1
      from public.player_active_sessions pas
      where pas.user_id = grm.user_id
        and pas.last_heartbeat_at >= v_stale_before
    );

  begin
    delete from public.load_test_ghosts g
    using public.game_room_instances gri
    where g.room_instance_id = gri.id
      and gri.room_type = v_room_type
      and g.last_heartbeat_at < v_stale_before;
  exception when undefined_table then
    null;
  end;

  update public.game_room_instances gri
  set
    status = 'closed',
    real_player_count = 0,
    leader_radius = 25,
    peak_leader_radius = 25,
    leader_radius_synced_at = null,
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and public._room_occupancy(gri.id) = 0
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before;

  update public.game_room_instances gri
  set
    real_player_count = least(v_cap, public._room_occupancy(gri.id)),
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and public._room_occupancy(gri.id) > 0;

  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.leader_radius < 250
    and public._room_occupancy(gri.id) < v_cap
    and public._room_occupancy(gri.id) > 0
  order by public._room_occupancy(gri.id) desc, gri.instance_number asc
  limit 1
  for update;

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

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, v_user_id);

  v_occ := public._sync_room_occupancy(v_room.id);

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

revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;
