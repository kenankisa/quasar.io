-- =============================================================================
-- Quasar.io — M5 güvenlik sertleştirme
-- - Helper RPC EXECUTE revoke + mesaj insert authz
-- - peak_leader_radius + radius rate-limit (ödül forge kapatma)
-- - apply_match_result zafer / placement doğrulama
-- - Avatar URL allowlist, leaderboard SELECT kapatma, get_user_rank sıkılaştırma
-- SQL Editor'da migration_security_m1_m4.sql sonrasında çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Helper fonksiyonlar — istemci EXECUTE kaldırma
-- -----------------------------------------------------------------------------

revoke all on function public._messaging_insert_message(uuid, uuid, text, text)
  from public, anon, authenticated;
revoke all on function public._messaging_trim(text, int)
  from public, anon, authenticated;
revoke all on function public._messaging_thread_json(public.admin_message_threads)
  from public, anon, authenticated;
revoke all on function public._messaging_message_json(public.admin_messages)
  from public, anon, authenticated;
revoke all on function public._messaging_enforce_player_limits(uuid, boolean)
  from public, anon, authenticated;
revoke all on function public._close_open_play_sessions(uuid, text)
  from public, anon, authenticated;
revoke all on function public._admin_user_ids()
  from public, anon, authenticated;
revoke all on function public._purge_stale_player_sessions()
  from public, anon, authenticated;
revoke all on function public._allow_trusted_profile_write()
  from public, anon, authenticated;
revoke all on function public._analytics_window_start(text)
  from public, anon, authenticated;
revoke all on function public._require_admin()
  from public, anon, authenticated;

-- _is_admin_user RLS politikalarında kullanılıyor — authenticated EXECUTE kalsın.
grant execute on function public._is_admin_user(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 2) Mesaj insert — auth + rol zorunlu (belt & suspenders)
-- -----------------------------------------------------------------------------

create or replace function public._messaging_insert_message(
  p_thread_id uuid,
  p_sender_id uuid,
  p_sender_role text,
  p_body text
)
returns public.admin_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := lower(trim(coalesce(p_sender_role, '')));
  v_body text := public._messaging_trim(p_body, 4000);
  v_msg public.admin_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_sender_id is distinct from v_uid then
    raise exception 'forbidden';
  end if;

  if v_role = 'admin' then
    perform public._require_admin();
  elsif v_role <> 'player' then
    raise exception 'invalid_sender_role';
  end if;

  if length(v_body) < 1 then
    raise exception 'empty_body';
  end if;

  insert into public.admin_messages (thread_id, sender_id, sender_role, body)
  values (p_thread_id, p_sender_id, v_role, v_body)
  returning * into v_msg;

  update public.admin_message_threads
  set
    last_message_at = v_msg.created_at,
    updated_at = timezone('utc', now()),
    status = case when status = 'closed' then 'open' else status end
  where id = p_thread_id;

  return v_msg;
end;
$$;

revoke all on function public._messaging_insert_message(uuid, uuid, text, text)
  from public, anon, authenticated;

-- Analytics session kapatma: yalnızca kendi uid
create or replace function public._close_open_play_sessions(
  p_user_id uuid,
  p_room_type text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := nullif(lower(trim(p_room_type)), '');
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_user_id is distinct from v_uid and not public._is_admin_user(v_uid) then
    raise exception 'forbidden';
  end if;

  update public.analytics_play_sessions
  set
    ended_at = timezone('utc', now()),
    duration_seconds = greatest(
      0,
      least(
        21600,
        floor(extract(epoch from (timezone('utc', now()) - started_at)))::int
      )
    )
  where user_id = p_user_id
    and ended_at is null
    and (v_room is null or room_type = v_room);
end;
$$;

revoke all on function public._close_open_play_sessions(uuid, text)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3) peak_leader_radius + güvenli radius sync
-- -----------------------------------------------------------------------------

alter table public.game_room_instances
  add column if not exists peak_leader_radius int not null default 25;

alter table public.game_room_instances
  add column if not exists leader_radius_synced_at timestamptz;

update public.game_room_instances
set peak_leader_radius = greatest(peak_leader_radius, leader_radius)
where peak_leader_radius < leader_radius;

create or replace function public.update_room_leader_radius(
  p_room_instance_id uuid,
  p_leader_radius int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_new int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_leader_radius < 0 or p_leader_radius > 550 then
    raise exception 'invalid leader_radius';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    raise exception 'not an active room member';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found or v_room.status <> 'open' then
    return;
  end if;

  -- En fazla ~4 sn'de bir sync; tek adımda +50 (25→350 ≈ 25 sn, sahte sıçrama yok).
  if v_room.leader_radius_synced_at is not null
     and v_room.leader_radius_synced_at > timezone('utc', now()) - interval '4 seconds' then
    return;
  end if;

  v_new := least(
    550,
    greatest(v_room.leader_radius, least(p_leader_radius, v_room.leader_radius + 50))
  );

  if v_new <= v_room.leader_radius then
    update public.game_room_instances
    set leader_radius_synced_at = timezone('utc', now())
    where id = p_room_instance_id;
    return;
  end if;

  update public.game_room_instances
  set
    leader_radius = v_new,
    peak_leader_radius = greatest(peak_leader_radius, v_new),
    leader_radius_synced_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

grant execute on function public.update_room_leader_radius(uuid, int) to authenticated;

-- close: peak korunur (ödül doğrulaması için); leader_radius reset edilir
create or replace function public.close_game_room(p_room_instance_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    raise exception 'not an active room member';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found or v_room.status <> 'open' then
    return;
  end if;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = p_room_instance_id
    and user_id = v_uid
    and left_at is null;

  update public.game_room_instances
  set
    real_player_count = (
      select count(*)::int
      from public.game_room_members grm
      where grm.room_instance_id = p_room_instance_id
        and grm.left_at is null
    ),
    peak_leader_radius = greatest(peak_leader_radius, leader_radius),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
  returning * into v_room;

  if v_room.leader_radius < 400 and v_room.real_player_count > 0 then
    return;
  end if;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = p_room_instance_id
    and left_at is null;

  update public.game_room_instances
  set
    status = 'closed',
    real_player_count = 0,
    peak_leader_radius = greatest(peak_leader_radius, leader_radius),
    leader_radius = 25,
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

grant execute on function public.close_game_room(uuid) to authenticated;

-- Oda başına tek 1. sıra ödülü
create unique index if not exists match_reward_claims_first_place_uidx
  on public.match_reward_claims (room_instance_id)
  where claim_kind = 'reward'
    and placement = 1
    and room_instance_id is not null;

-- -----------------------------------------------------------------------------
-- 4) apply_match_result — sunucu tarafı zafer / placement doğrulama
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

      -- 1. sıra: peak >= 350 (oda kapalı olsa bile peak şart — erken close forge yok)
      if v_kind = 'reward' and p_placement = 1 then
        if v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;

      -- 2/3: anlamlı ilerleme (peak) olmadan ödül yok
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
        diamond_delta
      )
      values (
        v_uid,
        v_room,
        case when v_room = 'simple' then null else p_room_instance_id end,
        v_session.id,
        v_kind,
        case when v_kind = 'penalty' then null else p_placement end,
        v_delta
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

grant execute on function public.apply_match_result(text, int, boolean, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Avatar URL allowlist + profil güncelleme
-- -----------------------------------------------------------------------------

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
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_trimmed := trim(p_username);

  if char_length(v_trimmed) < 3 or char_length(v_trimmed) > 12 then
    raise exception 'invalid_username_length';
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
    -- Yalnızca kendi Supabase Storage avatar yolu
    if v_avatar !~ (
      '^https://[a-z0-9.-]+/storage/v1/object/public/avatars/'
      || v_uid::text
      || '/avatar\.(jpg|jpeg|png|webp)$'
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

-- -----------------------------------------------------------------------------
-- 6) Leaderboard tablo okuma kapat + get_user_rank sıkılaştır
-- -----------------------------------------------------------------------------

drop policy if exists "Skorları herkes görebilir" on public.leaderboard;
revoke select on public.leaderboard from public, anon, authenticated;

-- Kendi satırını okuma (gerekirse); yazılar zaten RPC-only.
create policy "Kullanıcı kendi skorunu görebilir"
  on public.leaderboard
  for select
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.get_user_rank(user_uuid uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  user_position int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if user_uuid is distinct from v_uid
     and not public._is_admin_user(v_uid) then
    raise exception 'forbidden';
  end if;

  select position into user_position
  from (
    select
      id,
      row_number() over (
        order by diamonds desc, games_won desc, gold desc
      ) as position
    from public.profiles
    where not public._is_admin_user(id)
  ) ranked
  where id = user_uuid;

  return coalesce(user_position, 0);
end;
$$;

revoke all on function public.get_user_rank(uuid) from public, anon;
grant execute on function public.get_user_rank(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 7) Leaderboard score — son play session şartı
-- -----------------------------------------------------------------------------

create or replace function public.save_leaderboard_score(
  p_max_mass int,
  p_room_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_username text;
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_max_mass < 0 or p_max_mass > 500 then
    raise exception 'invalid max_mass';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if not exists (
    select 1
    from public.analytics_play_sessions s
    where s.user_id = v_uid
      and s.room_type = v_room
      and s.started_at <= timezone('utc', now()) - interval '30 seconds'
      and (
        s.ended_at is null
        or s.ended_at >= timezone('utc', now()) - interval '30 minutes'
      )
  ) then
    raise exception 'no_play_session';
  end if;

  select username into v_username
  from public.profiles
  where id = v_uid;

  insert into public.leaderboard (user_id, username, max_mass, room_type, updated_at)
  values (
    v_uid,
    coalesce(v_username, 'Traveler'),
    p_max_mass,
    v_room,
    timezone('utc', now())
  )
  on conflict (user_id) do update set
    max_mass = greatest(public.leaderboard.max_mass, excluded.max_mass),
    username = excluded.username,
    room_type = excluded.room_type,
    updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.save_leaderboard_score(int, text) from public;
grant execute on function public.save_leaderboard_score(int, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 8) join_game_room — oda reopen'da peak sıfırla (eski zafer kanıtı taşımasın)
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
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before;

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
    and (
      not exists (
        select 1
        from public.game_room_members grm
        where grm.room_instance_id = gri.id
          and grm.left_at is null
      )
      or coalesce(gri.updated_at, gri.created_at) < v_stale_before
    );

  update public.game_room_instances gri
  set
    real_player_count = sub.cnt,
    updated_at = timezone('utc', now())
  from (
    select grm.room_instance_id, count(*)::int as cnt
    from public.game_room_members grm
    where grm.left_at is null
    group by grm.room_instance_id
  ) as sub
  where gri.id = sub.room_instance_id
    and gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.real_player_count != sub.cnt;

  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.leader_radius < 250
    and gri.real_player_count < 20
    and coalesce(gri.updated_at, gri.created_at) >= v_stale_before
    and exists (
      select 1
      from public.game_room_members grm
      where grm.room_instance_id = gri.id
        and grm.left_at is null
    )
  order by gri.instance_number asc
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

  update public.game_room_instances
  set
    real_player_count = real_player_count + 1,
    updated_at = timezone('utc', now())
  where id = v_room.id
  returning * into v_room;

  return json_build_object(
    'room_instance_id', v_room.id,
    'instance_number', v_room.instance_number,
    'real_player_count', v_room.real_player_count,
    'leader_radius', v_room.leader_radius
  );
end;
$$;

revoke all on function public.join_game_room(text) from public;
grant execute on function public.join_game_room(text) to authenticated;
