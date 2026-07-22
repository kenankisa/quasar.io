-- =============================================================================
-- Quasar.io — Sim odasına katıl + bayat oda hatasını düzelt
-- SQL Editor'da çalıştırın.
--
-- Sorun: Sim odaları updated_at güncellemediği için ~3 dk sonra "bayat"
-- sayılıp kapanıyor; telefon yeni boş odaya düşüp sadece bot görüyordu.
-- =============================================================================

-- Sim heartbeat'in odayı taze tutması
create or replace function public.touch_game_room(p_room_instance_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or p_room_instance_id is null then
    return;
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    return;
  end if;

  update public.game_room_instances
  set updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

revoke all on function public.touch_game_room(uuid) from public, anon;
grant execute on function public.touch_game_room(uuid) to authenticated;

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

  if public._room_occupancy(v_room.id) >= 10 then
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

-- Aktif sim odalarını listele (telefon / admin)
create or replace function public.list_sim_load_test_rooms()
returns json
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  return coalesce(
    (
      select json_agg(row_to_json(t) order by t.players desc, t.instance_number)
      from (
        select
          gri.id as room_instance_id,
          gri.room_type,
          gri.instance_number,
          count(*)::int as players,
          gri.leader_radius,
          gri.status
        from public.game_room_instances gri
        join public.game_room_members grm
          on grm.room_instance_id = gri.id
         and grm.left_at is null
        join auth.users u on u.id = grm.user_id
        where gri.status = 'open'
          and (
            coalesce(u.raw_user_meta_data->>'is_sim', '') = 'true'
            or coalesce(u.email, '') like 'sim.%@example.com'
            or coalesce(u.email, '') like 'sim.%@quasar.sim.local'
          )
        group by gri.id, gri.room_type, gri.instance_number, gri.leader_radius, gri.status
      ) t
    ),
    '[]'::json
  );
end;
$$;

revoke all on function public.list_sim_load_test_rooms() from public, anon;
grant execute on function public.list_sim_load_test_rooms() to authenticated;

-- join_game_room: dolu sim odalarını tercih et; oyuncusu olan odayı bayat diye kapatma
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

  -- Bayat üyeleri temizle
  update public.game_room_members grm
  set left_at = timezone('utc', now())
  from public.game_room_instances gri
  where grm.room_instance_id = gri.id
    and gri.room_type = v_room_type
    and grm.left_at is null
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before
    and not exists (
      -- Aktif oturumu olan (sim dahil) üyeyi bayat diye atma
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

  -- Oyuncusu olan odaları kapatma; sadece boş + bayat odaları kapat
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

  -- Aktif dolu odaları taze tut
  update public.game_room_instances gri
  set
    real_player_count = least(10, public._room_occupancy(gri.id)),
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and public._room_occupancy(gri.id) > 0;

  -- Önce en dolu açık oda (sim'lerin olduğu) — max 10 gerçek oyuncu
  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.leader_radius < 250
    and public._room_occupancy(gri.id) < 10
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
        status
      )
      values (v_room_type, v_next_instance, 0, 25, 25, 'open')
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
