-- =============================================================================
-- Quasar.io — Yük testi için ayrı Test odaları
--
-- Normal / Elit / Eşsiz oyun odaları ile YÜK TESTİ odaları tamamen ayrıdır.
-- Test odaları: "Normal Evren Test1", "Normal Evren Test2", ...
-- Gerçek oyuncular bu odalara düşmez; yalnızca sim + admin (izleme).
--
-- SQL Editor'da TAMAMINI çalıştırın
-- (isolation / reaper migration'larından sonra önerilir).
-- =============================================================================

-- Sim tespiti (isolation migration yoksa da çalışsın)
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

-- -----------------------------------------------------------------------------
-- 1) Şema: is_load_test + ayrı instance numarası
-- -----------------------------------------------------------------------------
alter table public.game_room_instances
  add column if not exists is_load_test boolean not null default false;

-- Eski unique (room_type, instance_number) → havuz bazlı
alter table public.game_room_instances
  drop constraint if exists game_room_instances_room_type_instance_number_key;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'game_room_instances_room_type_instance_number_key'
  ) then
    alter table public.game_room_instances
      drop constraint game_room_instances_room_type_instance_number_key;
  end if;
end $$;

-- Bazı projelerde unique index adı farklı olabilir
drop index if exists game_room_instances_room_type_instance_number_key;

alter table public.game_room_instances
  drop constraint if exists game_room_instances_type_pool_instance_key;

alter table public.game_room_instances
  add constraint game_room_instances_type_pool_instance_key
  unique (room_type, is_load_test, instance_number);

create index if not exists game_room_instances_load_test_mm_idx
  on public.game_room_instances (
    room_type, is_load_test, status, leader_radius, instance_number
  )
  where status = 'open';

comment on column public.game_room_instances.is_load_test is
  'true = yük testi odası (Test1, Test2…); normal matchmaking asla seçmez.';

-- Lobi: insan odalarında insan sayısı; Test odalarında toplam (sim+ghost)
create or replace function public._sync_room_occupancy(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_cap int := public._max_real_players_per_room();
  v_is_load_test boolean := false;
begin
  select coalesce(is_load_test, false)
  into v_is_load_test
  from public.game_room_instances
  where id = p_room_id;

  if v_is_load_test then
    v_count := public._room_occupancy(p_room_id);
  else
    begin
      v_count := public._room_human_occupancy(p_room_id);
    exception when undefined_function then
      v_count := public._room_occupancy(p_room_id);
    end;
  end if;

  update public.game_room_instances
  set
    real_player_count = least(v_cap, greatest(0, v_count)),
    updated_at = timezone('utc', now())
  where id = p_room_id;

  return least(v_cap, greatest(0, v_count));
end;
$$;

revoke all on function public._sync_room_occupancy(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2) join_game_room — sim → load-test havuzu; insan → normal havuz
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
  v_is_load_test boolean := false;
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
  v_is_load_test := v_is_sim;

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

  perform pg_advisory_xact_lock(
    hashtext('join_game_room_' || v_room_type || '_' || v_is_load_test::text)
  );

  begin
    perform public._purge_stale_room_occupancy(v_room_type);
  exception when undefined_function then
    null;
  end;

  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.is_load_test = v_is_load_test
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
      and is_load_test = v_is_load_test
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
      where room_type = v_room_type
        and is_load_test = v_is_load_test;

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
        v_room_type, v_next_instance, 0, 25, 25, 1, 'open', v_is_load_test
      )
      returning * into v_room;
    end if;
  end if;

  if v_room.is_load_test <> v_is_load_test then
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
    'match_generation', coalesce(v_room.match_generation, 1),
    'is_load_test', v_room.is_load_test
  );
end;
$$;

revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) join_game_room_instance — load-test odasına yalnız sim veya admin
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

  if v_room.is_load_test and not v_is_sim and not v_is_admin then
    raise exception 'load_test_room_forbidden';
  end if;

  if not v_room.is_load_test and v_is_sim then
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
    'room_type', v_room.room_type,
    'is_load_test', v_room.is_load_test
  );
end;
$$;

revoke all on function public.join_game_room_instance(uuid) from public, anon;
grant execute on function public.join_game_room_instance(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) list_sim_load_test_rooms — yalnızca is_load_test odaları
-- -----------------------------------------------------------------------------
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
          gri.status,
          true as is_load_test
        from public.game_room_instances gri
        join public.game_room_members grm
          on grm.room_instance_id = gri.id
         and grm.left_at is null
        join auth.users u on u.id = grm.user_id
        where gri.status = 'open'
          and gri.is_load_test = true
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

-- -----------------------------------------------------------------------------
-- 5) Ghost yerleştirme — yalnız load-test havuzu
-- -----------------------------------------------------------------------------
create or replace function public._load_test_place_ghost(
  p_ghost_id uuid,
  p_room_type text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_type text := lower(trim(p_room_type));
  v_room public.game_room_instances%rowtype;
  v_next_instance int;
  v_cap int := public._max_real_players_per_room();
  v_occ int;
begin
  if v_room_type not in ('normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('join_game_room_' || v_room_type || '_true')
  );

  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.is_load_test = true
    and gri.status = 'open'
    and gri.leader_radius < 280
    and public._room_occupancy(gri.id) < v_cap
  order by public._room_occupancy(gri.id) desc, gri.instance_number asc
  limit 1
  for update;

  if not found then
    select *
    into v_room
    from public.game_room_instances
    where room_type = v_room_type
      and is_load_test = true
      and status = 'closed'
    order by instance_number asc
    limit 1
    for update;

    if found then
      delete from public.game_room_members where room_instance_id = v_room.id;
      delete from public.load_test_ghosts where room_instance_id = v_room.id;

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
      where room_type = v_room_type
        and is_load_test = true;

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
      values (v_room_type, v_next_instance, 0, 25, 25, 1, 'open', true)
      returning * into v_room;
    end if;
  end if;

  update public.load_test_ghosts
  set
    room_type = v_room_type,
    room_instance_id = v_room.id,
    last_heartbeat_at = timezone('utc', now())
  where id = p_ghost_id;

  v_occ := public._sync_room_occupancy(v_room.id);
  return v_room.id;
end;
$$;

revoke all on function public._load_test_place_ghost(uuid, text)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6) Geriye dönük: sim/ghost dolu odaları load-test olarak işaretle
--    Karışık odalardan sim'leri çıkar; boş load-test sayaçlarını düzelt
-- -----------------------------------------------------------------------------
update public.game_room_instances gri
set is_load_test = true
where gri.status = 'open'
  and gri.is_load_test = false
  and (
    exists (
      select 1
      from public.game_room_members grm
      where grm.room_instance_id = gri.id
        and grm.left_at is null
        and public._is_sim_auth_user(grm.user_id)
    )
    or exists (
      select 1
      from public.load_test_ghosts g
      where g.room_instance_id = gri.id
    )
  );

-- İnsan + sim karışığı: sim üyelerini çıkar (insan odası kalsın)
update public.game_room_members grm
set left_at = timezone('utc', now())
from public.game_room_instances gri
where grm.room_instance_id = gri.id
  and gri.status = 'open'
  and gri.is_load_test = false
  and grm.left_at is null
  and public._is_sim_auth_user(grm.user_id);

delete from public.load_test_ghosts g
using public.game_room_instances gri
where g.room_instance_id = gri.id
  and gri.is_load_test = false;

-- Instance numarası çakışmasını çöz: load-test satırlarını yeniden numarala
do $$
declare
  rt text;
  rid uuid;
  n int;
begin
  for rt in
    select distinct room_type
    from public.game_room_instances
    where is_load_test = true
  loop
    n := 0;
    for rid in
      select id
      from public.game_room_instances
      where room_type = rt
        and is_load_test = true
      order by instance_number, created_at
    loop
      n := n + 1;
      update public.game_room_instances
      set instance_number = n + 100000
      where id = rid;
    end loop;

    n := 0;
    for rid in
      select id
      from public.game_room_instances
      where room_type = rt
        and is_load_test = true
      order by instance_number, created_at
    loop
      n := n + 1;
      update public.game_room_instances
      set instance_number = n
      where id = rid;
    end loop;
  end loop;
end $$;

do $$
declare
  r record;
begin
  for r in select id from public.game_room_instances where status = 'open'
  loop
    perform public._sync_room_occupancy(r.id);
  end loop;
end $$;
