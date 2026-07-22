-- =============================================================================
-- Quasar.io — Her maçta hak edilen ödül (oda yeniden kullanımı düzeltmesi)
--
-- Sorun: join_game_room kapalı odaları AYNI uuid ile reopen ediyor.
-- match_reward_claims indeksleri (user, room) ve (room, 1. sıra) ömür boyu
-- tek claim varsayıyordu → ilk 1. sıra ödülü sonrası already_claimed.
--
-- Çözüm: match_generation — her reopen yeni maç nesli; claim indeksleri
-- (room, generation) kapsamında. Play session cooldown da maç bitince
-- yeni oturuma izin verir.
--
-- SQL Editor'da migration_room_capacity_10.sql sonrası çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Şema
-- -----------------------------------------------------------------------------

alter table public.game_room_instances
  add column if not exists match_generation int not null default 1;

alter table public.match_reward_claims
  add column if not exists match_generation int;

comment on column public.game_room_instances.match_generation is
  'Increments each time a closed room is reopened; scopes reward claims per match.';

comment on column public.match_reward_claims.match_generation is
  'Room match_generation at claim time; null for training / legacy rows.';

-- Ömür boyu oda indekslerini kaldır (reopen ile çakışıyordu)
drop index if exists public.match_reward_claims_first_place_uidx;
drop index if exists public.match_reward_claims_room_uidx;

-- Maç nesli başına tek 1. sıra + kullanıcı başına tek sonuç
create unique index if not exists match_reward_claims_first_place_gen_uidx
  on public.match_reward_claims (room_instance_id, match_generation)
  where claim_kind = 'reward'
    and placement = 1
    and room_instance_id is not null
    and match_generation is not null;

create unique index if not exists match_reward_claims_room_gen_uidx
  on public.match_reward_claims (user_id, room_instance_id, match_generation)
  where room_instance_id is not null
    and match_generation is not null;

-- Oturum indeksi kalır (aynı play_session'a çift kayıt yok)
-- match_reward_claims_session_uidx

-- -----------------------------------------------------------------------------
-- 2) Play session: bitmiş / ödüllenmiş oturumdan sonra cooldown'u aş
-- -----------------------------------------------------------------------------

create or replace function public.analytics_begin_play_session(p_room_type text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room text := lower(trim(coalesce(p_room_type, '')));
  v_id uuid;
  v_recent int;
  v_day_count int;
  v_recent_resolved boolean := false;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if public._is_admin_user(v_user_id) then
    return null;
  end if;

  select count(*)::int
  into v_recent
  from public.analytics_play_sessions
  where user_id = v_user_id
    and started_at > timezone('utc', now()) - interval '45 seconds';

  if coalesce(v_recent, 0) > 0 then
    -- Son 45 sn içindeki oturum zaten bittiyse veya claim aldıysa yeni maça izin ver
    select exists (
      select 1
      from public.analytics_play_sessions s
      where s.user_id = v_user_id
        and s.started_at > timezone('utc', now()) - interval '45 seconds'
        and (
          s.ended_at is not null
          or exists (
            select 1
            from public.match_reward_claims c
            where c.play_session_id = s.id
          )
        )
    )
    into v_recent_resolved;

    if not coalesce(v_recent_resolved, false) then
      -- Açık, henüz claim'siz oturumu yeniden kullan
      select s.id
      into v_id
      from public.analytics_play_sessions s
      where s.user_id = v_user_id
        and s.ended_at is null
        and s.room_type = v_room
        and not exists (
          select 1
          from public.match_reward_claims c
          where c.play_session_id = s.id
        )
      order by s.started_at desc
      limit 1;

      if v_id is not null then
        return v_id;
      end if;

      raise exception 'play_session_cooldown';
    end if;
  end if;

  select count(*)::int
  into v_day_count
  from public.analytics_play_sessions
  where user_id = v_user_id
    and started_at >= timezone('utc', now()) - interval '24 hours';

  if coalesce(v_day_count, 0) >= 40 then
    raise exception 'play_session_daily_limit';
  end if;

  perform public._close_open_play_sessions(v_user_id, null);

  insert into public.analytics_play_sessions (user_id, room_type)
  values (v_user_id, v_room)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.analytics_begin_play_session(text) from public;
grant execute on function public.analytics_begin_play_session(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) apply_match_result — match_generation ile claim
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
          v_won := 1;
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
  end if;

  if v_delta = 0 and v_won = 0 then
    select diamonds into v_new_diamonds
    from public.profiles
    where id = v_uid;
    return coalesce(v_new_diamonds, 0);
  end if;

  if not public._is_admin_user(v_uid) then
    if v_room = 'simple' then
      v_min_seconds := 90;
    end if;

    -- Önce claim'siz oturum; yoksa en son oturum (çift kayıt session_uidx ile engellenir)
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
-- 4) join_game_room — reopen'da match_generation++
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
    'room_type', v_room.room_type,
    'match_generation', coalesce(v_room.match_generation, 1)
  );
end;
$$;

revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;
