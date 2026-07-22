-- =============================================================================
-- Quasar.io — M1–M4 güvenlik
-- M1: Admin role (app_metadata + admin_users)
-- M2: Mesajlaşma rate limit
-- M3: Maç oturumu doğrulama güçlendirme
-- M4: Profil gizliliği + leaderboard / admin RPC
-- SQL Editor'da migration_economy_security.sql sonrasında çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- M1) Admin allowlist — e-posta yerine role / tablo
-- -----------------------------------------------------------------------------

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.admin_users enable row level security;
revoke all on public.admin_users from public, anon, authenticated;

-- Mevcut sahip hesabını bir kez seed et (yalnızca SQL; client'ta e-posta yok).
insert into public.admin_users (user_id)
select u.id
from auth.users u
where lower(coalesce(u.email, '')) = 'kenankisa@gmail.com'
on conflict (user_id) do nothing;

update auth.users u
set raw_app_meta_data =
  coalesce(u.raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where lower(coalesce(u.email, '')) = 'kenankisa@gmail.com'
  and coalesce(u.raw_app_meta_data->>'role', '') is distinct from 'admin';

create or replace function public._is_admin_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_user_id is not null
    and (
      exists (
        select 1
        from public.admin_users a
        where a.user_id = p_user_id
      )
      or exists (
        select 1
        from auth.users u
        where u.id = p_user_id
          and coalesce(u.raw_app_meta_data->>'role', '') = 'admin'
      )
    );
$$;

create or replace function public._require_admin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin' then
    return;
  end if;
  if not public._is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;
end;
$$;

create or replace function public.is_current_user_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return false;
  end if;
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin' then
    return true;
  end if;
  return public._is_admin_user(auth.uid());
end;
$$;

grant execute on function public.is_current_user_admin() to authenticated;

-- Tuning / session politikalarını role helper'a bağla
drop policy if exists "room_game_tuning_upsert_admin" on public.room_game_tuning;
create policy "room_game_tuning_upsert_admin"
  on public.room_game_tuning
  for all
  to authenticated
  using (public._is_admin_user(auth.uid()))
  with check (public._is_admin_user(auth.uid()));

do $$
begin
  if to_regclass('public.bot_tuning') is not null then
    execute 'drop policy if exists "bot_tuning_upsert_admin" on public.bot_tuning';
    execute $pol$
      create policy "bot_tuning_upsert_admin"
        on public.bot_tuning
        for all
        to authenticated
        using (public._is_admin_user(auth.uid()))
        with check (public._is_admin_user(auth.uid()))
    $pol$;
  end if;
end $$;

drop policy if exists "Admin tüm oturumları görebilir" on public.player_active_sessions;
create policy "Admin tüm oturumları görebilir"
  on public.player_active_sessions
  for select
  to authenticated
  using (public._is_admin_user(auth.uid()));

create or replace function public.get_admin_active_session_count()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  perform public._require_admin();

  perform public._purge_stale_player_sessions();

  select count(*)::int
  into v_count
  from public.player_active_sessions s
  where not public._is_admin_user(s.user_id);

  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.get_admin_active_session_count() to authenticated;

-- -----------------------------------------------------------------------------
-- M2) Mesajlaşma rate limit
-- -----------------------------------------------------------------------------

create or replace function public._messaging_enforce_player_limits(
  p_uid uuid,
  p_is_new_thread boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_open_threads int;
  v_threads_1h int;
  v_msgs_1h int;
  v_last_thread_at timestamptz;
  v_last_msg_at timestamptz;
begin
  select count(*)::int
  into v_open_threads
  from public.admin_message_threads
  where player_id = p_uid
    and status = 'open'
    and category in ('feedback', 'suggestion', 'bug', 'direct');

  if p_is_new_thread and coalesce(v_open_threads, 0) >= 10 then
    raise exception 'too_many_open_threads';
  end if;

  select count(*)::int, max(created_at)
  into v_threads_1h, v_last_thread_at
  from public.admin_message_threads
  where player_id = p_uid
    and category in ('feedback', 'suggestion', 'bug')
    and created_at >= timezone('utc', now()) - interval '1 hour';

  if p_is_new_thread then
    if coalesce(v_threads_1h, 0) >= 5 then
      raise exception 'thread_hourly_limit';
    end if;
    if v_last_thread_at is not null
       and v_last_thread_at > timezone('utc', now()) - interval '60 seconds' then
      raise exception 'thread_cooldown';
    end if;
  end if;

  select count(*)::int, max(m.created_at)
  into v_msgs_1h, v_last_msg_at
  from public.admin_messages m
  join public.admin_message_threads t on t.id = m.thread_id
  where t.player_id = p_uid
    and m.sender_role = 'player'
    and m.created_at >= timezone('utc', now()) - interval '1 hour';

  if coalesce(v_msgs_1h, 0) >= 30 then
    raise exception 'message_hourly_limit';
  end if;

  if v_last_msg_at is not null
     and v_last_msg_at > timezone('utc', now()) - interval '15 seconds' then
    raise exception 'message_cooldown';
  end if;
end;
$$;

create or replace function public.submit_player_message(
  p_category text,
  p_subject text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_category text := lower(trim(coalesce(p_category, '')));
  v_subject text := public._messaging_trim(p_subject, 120);
  v_thread public.admin_message_threads;
  v_msg public.admin_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_category not in ('feedback', 'suggestion', 'bug') then
    raise exception 'invalid_category';
  end if;

  perform public._messaging_enforce_player_limits(v_uid, true);

  if length(v_subject) < 1 then
    v_subject := case v_category
      when 'bug' then 'Bug report'
      when 'suggestion' then 'Suggestion'
      else 'Feedback'
    end;
  end if;

  insert into public.admin_message_threads (player_id, category, subject)
  values (v_uid, v_category, v_subject)
  returning * into v_thread;

  v_msg := public._messaging_insert_message(v_thread.id, v_uid, 'player', p_body);

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'message', public._messaging_message_json(v_msg)
  );
end;
$$;

grant execute on function public.submit_player_message(text, text, text) to authenticated;

create or replace function public.player_reply_to_thread(
  p_thread_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_thread public.admin_message_threads;
  v_msg public.admin_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_thread
  from public.admin_message_threads
  where id = p_thread_id and player_id = v_uid
  for update;

  if not found then
    raise exception 'not found';
  end if;

  if v_thread.category = 'broadcast' then
    raise exception 'cannot_reply_broadcast';
  end if;

  perform public._messaging_enforce_player_limits(v_uid, false);

  v_msg := public._messaging_insert_message(p_thread_id, v_uid, 'player', p_body);

  select * into v_thread from public.admin_message_threads where id = p_thread_id;

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'message', public._messaging_message_json(v_msg)
  );
end;
$$;

grant execute on function public.player_reply_to_thread(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- M3) Maç oturumu — play session zorunlu + zafer yarıçapı + günlük elmas tavanı
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
  v_last_reward_at timestamptz;
  v_day_diamonds int;
  v_min_seconds int := 60;
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
    -- Her oda tipi için play session zorunlu
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

      -- 1. sıra: sunucuda zafer yarıçapına yakınlık veya oda kapalı
      if v_kind = 'reward' and p_placement = 1 then
        if v_room_row.status = 'open' and v_room_row.leader_radius < 350 then
          raise exception 'victory_not_verified';
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
-- M4) Profil gizliliği + public leaderboard + admin oyuncu özeti
-- -----------------------------------------------------------------------------

drop policy if exists "Profilleri herkes görebilir" on public.profiles;
drop policy if exists "Kullanıcı kendi profilini görebilir" on public.profiles;
create policy "Kullanıcı kendi profilini görebilir"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

-- Anon artık profil okuyamaz (leaderboard RPC ile gider).
revoke select on public.profiles from anon;

create or replace function public.get_global_leaderboard(p_limit int default 100)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 100);
  v_top json;
  v_local json;
  v_local_rank int;
  v_in_top boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
  into v_top
  from (
    select
      row_number() over (
        order by p.diamonds desc, p.games_won desc, p.gold desc
      ) as rank_pos,
      p.id as user_id,
      coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
      p.diamonds
    from public.profiles p
    where not public._is_admin_user(p.id)
    order by p.diamonds desc, p.games_won desc, p.gold desc
    limit v_limit
  ) t;

  select exists (
    select 1
    from json_array_elements(v_top) e
    where (e->>'user_id')::uuid = v_uid
  ) into v_in_top;

  if not v_in_top then
    select position into v_local_rank
    from (
      select
        id,
        row_number() over (
          order by diamonds desc, games_won desc, gold desc
        ) as position
      from public.profiles
      where not public._is_admin_user(id)
    ) ranked
    where id = v_uid;

    select json_build_object(
      'rank_pos', coalesce(v_local_rank, 0),
      'user_id', p.id,
      'username', coalesce(nullif(trim(p.username), ''), 'Traveler'),
      'diamonds', p.diamonds
    )
    into v_local
    from public.profiles p
    where p.id = v_uid;
  end if;

  return json_build_object(
    'top', v_top,
    'local', v_local,
    'local_in_top', v_in_top
  );
end;
$$;

grant execute on function public.get_global_leaderboard(int) to authenticated;

create or replace function public.get_admin_live_player_stats()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registered int;
  v_total_wins int;
  v_winners json;
begin
  perform public._require_admin();

  select count(*)::int, coalesce(sum(games_won), 0)::int
  into v_registered, v_total_wins
  from public.profiles p
  where not public._is_admin_user(p.id);

  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_winners
  from (
    select
      coalesce(nullif(trim(username), ''), '—') as username,
      games_won,
      diamonds
    from public.profiles p
    where not public._is_admin_user(p.id)
    order by games_won desc, diamonds desc
    limit 8
  ) t;

  return json_build_object(
    'registered_players', coalesce(v_registered, 0),
    'total_games_won', coalesce(v_total_wins, 0),
    'top_winners', v_winners
  );
end;
$$;

grant execute on function public.get_admin_live_player_stats() to authenticated;

-- get_user_rank zaten security definer; admin'i sıral dışı bırak
create or replace function public.get_user_rank(user_uuid uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  user_position int;
begin
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

grant execute on function public.get_user_rank(uuid) to authenticated;
grant execute on function public.get_user_rank(uuid) to anon;

-- Analytics admin exclusion helper (get_admin_analytics ileride buna geçebilir).
create or replace function public._admin_user_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select a.user_id from public.admin_users a
  union
  select u.id
  from auth.users u
  where coalesce(u.raw_app_meta_data->>'role', '') = 'admin';
$$;
