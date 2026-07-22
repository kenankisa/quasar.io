-- =============================================================================
-- Quasar.io — Bayat oda doluluğu temizliği
--
-- Sorun: Bir canlı istemci odayı taze tutunca, sekme kapatan / çöken diğer
-- üyeler game_room_members'ta kalıyor → lobide "9 oyuncu + 11 bot" gibi hayalet
-- doluluk. leave_game_room boş odayı kapatmıyordu.
--
-- Beklenen:
--   ilk oyuncu → 1 insan + 19 bot
--   max → 10 insan + 10 bot
--   biri çıkınca / yutulunca koltuk boşalır; lider < 280 ise yeni oyuncu aynı odaya
--   lider >= 280 → yeni oyuncu alınmaz (bot doldurması client-side)
--
-- SQL Editor'da TAMAMINI çalıştırın (capacity_10 / match_reward sonrası).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Üye bazlı bayat temizliği + boş oda kapatma
-- -----------------------------------------------------------------------------
create or replace function public._purge_stale_room_occupancy(
  p_room_type text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_stale timestamptz := timezone('utc', now()) - interval '90 seconds';
  v_ghost_stale timestamptz := timezone('utc', now()) - interval '90 seconds';
  v_room_type text := nullif(lower(trim(p_room_type)), '');
  v_rid uuid;
begin
  begin
    perform public._purge_stale_player_sessions();
  exception when undefined_function then
    null;
  end;

  -- Oda taze olsa bile: heartbeat'i olmayan / bayat üyeleri çıkar
  update public.game_room_members grm
  set left_at = timezone('utc', now())
  from public.game_room_instances gri
  where grm.room_instance_id = gri.id
    and grm.left_at is null
    and gri.status = 'open'
    and (v_room_type is null or gri.room_type = v_room_type)
    and not exists (
      select 1
      from public.player_active_sessions pas
      where pas.user_id = grm.user_id
        and pas.last_heartbeat_at >= v_member_stale
    );

  begin
    delete from public.load_test_ghosts g
    using public.game_room_instances gri
    where g.room_instance_id = gri.id
      and gri.status = 'open'
      and (v_room_type is null or gri.room_type = v_room_type)
      and g.last_heartbeat_at < v_ghost_stale;
  exception when undefined_table then
    null;
  end;

  for v_rid in
    select gri.id
    from public.game_room_instances gri
    where gri.status = 'open'
      and (v_room_type is null or gri.room_type = v_room_type)
  loop
    perform public._sync_room_occupancy(v_rid);

    if public._room_occupancy(v_rid) = 0 then
      update public.game_room_instances
      set
        status = 'closed',
        real_player_count = 0,
        leader_radius = 25,
        peak_leader_radius = 25,
        leader_radius_synced_at = null,
        updated_at = timezone('utc', now())
      where id = v_rid
        and status = 'open';
    end if;
  end loop;
end;
$$;

revoke all on function public._purge_stale_room_occupancy(text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2) leave_game_room — son koltuk boşalınca odayı kapat
-- -----------------------------------------------------------------------------
create or replace function public.leave_game_room(p_room_instance_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_member record;
  v_occ int;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  for v_member in
    select id, room_instance_id
    from public.game_room_members
    where user_id = v_user_id
      and left_at is null
      and (p_room_instance_id is null or room_instance_id = p_room_instance_id)
    for update
  loop
    update public.game_room_members
    set left_at = timezone('utc', now())
    where id = v_member.id;

    v_occ := public._sync_room_occupancy(v_member.room_instance_id);

    if coalesce(v_occ, 0) <= 0 then
      update public.game_room_instances
      set
        status = 'closed',
        real_player_count = 0,
        leader_radius = 25,
        peak_leader_radius = 25,
        leader_radius_synced_at = null,
        updated_at = timezone('utc', now())
      where id = v_member.room_instance_id
        and status = 'open';
    end if;
  end loop;
end;
$$;

revoke all on function public.leave_game_room(uuid) from public, anon;
grant execute on function public.leave_game_room(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) join_game_room — üye bazlı purge, sonra eşleştir
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

  -- Hayalet doluluğu temizle (oda updated_at taze olsa bile)
  perform public._purge_stale_room_occupancy(v_room_type);

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
    'room_type', v_room.room_type,
    'match_generation', coalesce(v_room.match_generation, 1)
  );
end;
$$;

revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) join_game_room_instance — join öncesi purge
-- -----------------------------------------------------------------------------
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

  perform public._purge_stale_room_occupancy(null);

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
-- 5) Şimdi bir kez temizle (mevcut hayalet 9'ları kapat)
-- -----------------------------------------------------------------------------
select public._purge_stale_room_occupancy(null);
