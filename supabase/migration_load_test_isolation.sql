-- =============================================================================
-- Quasar.io — Yük testi ↔ normal oyun izolasyonu
--
-- Yük testi sim/ghost oyuncuları SADECE yük testi içindir.
-- Normal oyuncular onların odasına düşmez; lobi sayıları onları onlarıları sayar.
--
-- SQL Editor'da TAMAMINI çalıştırın
-- (migration_room_occupancy_reaper.sql varsa ondan sonra).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Yardımcılar
-- -----------------------------------------------------------------------------
create or replace function public._is_sim_auth_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (
      select
        coalesce(u.raw_user_meta_data->>'is_sim', '') = 'true'
        or coalesce(u.email, '') like 'sim.%@example.com'
        or coalesce(u.email, '') like 'sim.%@quasar.sim.local'
      from auth.users u
      where u.id = p_user_id
    ),
    false
  );
$$;

revoke all on function public._is_sim_auth_user(uuid) from public, anon, authenticated;

-- Sadece gerçek (sim olmayan) üyeler — lobi / normal matchmaking
create or replace function public._room_human_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public, auth
as $$
  select count(*)::int
  from public.game_room_members grm
  where grm.room_instance_id = p_room_id
    and grm.left_at is null
    and not public._is_sim_auth_user(grm.user_id);
$$;

revoke all on function public._room_human_occupancy(uuid) from public, anon, authenticated;

-- Sim üyeler + ghost'lar
create or replace function public._room_load_test_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public, auth
as $$
  select (
    select count(*)::int
    from public.game_room_members grm
    where grm.room_instance_id = p_room_id
      and grm.left_at is null
      and public._is_sim_auth_user(grm.user_id)
  ) + (
    select count(*)::int
    from public.load_test_ghosts g
    where g.room_instance_id = p_room_id
  );
$$;

revoke all on function public._room_load_test_occupancy(uuid) from public, anon, authenticated;

-- Toplam doluluk (load test kapasite kontrolü)
create or replace function public._room_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select public._room_human_occupancy(p_room_id)
       + public._room_load_test_occupancy(p_room_id);
$$;

revoke all on function public._room_occupancy(uuid) from public, anon, authenticated;

create or replace function public._room_has_load_test(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public._room_load_test_occupancy(p_room_id) > 0;
$$;

revoke all on function public._room_has_load_test(uuid) from public, anon, authenticated;

create or replace function public._room_has_humans(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public._room_human_occupancy(p_room_id) > 0;
$$;

revoke all on function public._room_has_humans(uuid) from public, anon, authenticated;

-- Lobi kartı: yalnızca insan sayısı
create or replace function public._sync_room_occupancy(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_humans int;
  v_cap int := public._max_real_players_per_room();
begin
  v_humans := public._room_human_occupancy(p_room_id);
  update public.game_room_instances
  set
    real_player_count = least(v_cap, greatest(0, v_humans)),
    updated_at = timezone('utc', now())
  where id = p_room_id;
  return least(v_cap, greatest(0, v_humans));
end;
$$;

revoke all on function public._sync_room_occupancy(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2) leave_game_room — tamamen boşsa kapat (insan+sim+ghost yok)
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
  v_total int;
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

    perform public._sync_room_occupancy(v_member.room_instance_id);
    v_total := public._room_occupancy(v_member.room_instance_id);

    if coalesce(v_total, 0) <= 0 then
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
-- 3) join_game_room — insan ↔ sim ayrı havuz
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

  v_is_sim := public._is_sim_auth_user(v_user_id);

  -- Sim hesaplar elmas / first-login kilidine takılmaz
  if not v_is_sim and not public._is_admin_user(v_user_id) then
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

  -- Bayat temizlik (reaper yoksa zararsız no-op değil — fonksiyon varsa çağır)
  begin
    perform public._purge_stale_room_occupancy(v_room_type);
  exception when undefined_function then
    null;
  end;

  if v_is_sim then
    -- Yük testi havuzu: insanı olan odalara girme
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
    -- Normal oyun: yük testi (sim/ghost) odalarına girme
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

  -- Son güvenlik: karışık odaya yazmayı engelle
  if v_is_sim and public._room_has_humans(v_room.id) then
    raise exception 'load_test_room_conflict';
  end if;
  if not v_is_sim and public._room_has_load_test(v_room.id) then
    raise exception 'load_test_room_conflict';
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
-- 4) join_game_room_instance — admin sim izleme; normal kullanıcı load-test odasına zorlanmasın
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

  v_is_sim := public._is_sim_auth_user(v_user_id);
  v_is_admin := public._is_admin_user(v_user_id);

  -- Normal oyuncu → yük testi odası yasak (admin izleme hariç)
  if not v_is_sim and not v_is_admin and public._room_has_load_test(v_room.id) then
    raise exception 'load_test_room_forbidden';
  end if;

  -- Sim → insan odası yasak
  if v_is_sim and public._room_has_humans(v_room.id) then
    raise exception 'load_test_room_conflict';
  end if;

  if not v_is_sim and not v_is_admin then
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
-- 5) Mevcut sayaçları insan-only'a çek + boş yük testi karışık odaları düzelt
-- -----------------------------------------------------------------------------
update public.game_room_instances gri
set real_player_count = least(
  public._max_real_players_per_room(),
  public._room_human_occupancy(gri.id)
)
where gri.status = 'open';

-- Karışık odalarda sim üyelerini çıkar (insanlar kalsın) — izolasyonu geriye dönük temizle
update public.game_room_members grm
set left_at = timezone('utc', now())
from public.game_room_instances gri
where grm.room_instance_id = gri.id
  and gri.status = 'open'
  and grm.left_at is null
  and public._is_sim_auth_user(grm.user_id)
  and public._room_has_humans(gri.id);

-- İnsan + ghost karışığı: ghost'ları sil
delete from public.load_test_ghosts g
using public.game_room_instances gri
where g.room_instance_id = gri.id
  and gri.status = 'open'
  and public._room_has_humans(gri.id);

-- Sayaçları yeniden yaz
do $$
declare
  r record;
begin
  for r in select id from public.game_room_instances where status = 'open'
  loop
    perform public._sync_room_occupancy(r.id);
  end loop;
end $$;
