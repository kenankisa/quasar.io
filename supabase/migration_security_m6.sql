-- =============================================================================
-- Quasar.io — M6 Medium güvenlik
-- - Eski email-admin politikalarını yeniden _is_admin_user ile sabitle
-- - Play session / soft-farm rate limit
-- - Oda listesi anon SELECT kapat
-- - Analytics admin exclusion → _admin_user_ids
-- SQL Editor'da migration_security_m5.sql sonrasında çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Admin modelini yeniden sabitle (eski migration re-run footgun)
-- -----------------------------------------------------------------------------

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.admin_users enable row level security;
revoke all on public.admin_users from public, anon, authenticated;

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

grant execute on function public._is_admin_user(uuid) to authenticated;

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

revoke all on function public._require_admin() from public, anon, authenticated;

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

revoke all on function public._admin_user_ids() from public, anon, authenticated;

-- Tuning / session politikaları
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

revoke all on function public.get_admin_active_session_count() from public, anon;
grant execute on function public.get_admin_active_session_count() to authenticated;

-- -----------------------------------------------------------------------------
-- 2) Play session rate limit (soft-farm)
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

  -- En az 45 sn arayla yeni oturum
  select count(*)::int
  into v_recent
  from public.analytics_play_sessions
  where user_id = v_user_id
    and started_at > timezone('utc', now()) - interval '45 seconds';

  if coalesce(v_recent, 0) > 0 then
    raise exception 'play_session_cooldown';
  end if;

  -- Günde en fazla 40 play session
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
-- 3) Oda örnekleri — anon SELECT kapat
-- -----------------------------------------------------------------------------

drop policy if exists "Oda örneklerini herkes görebilir" on public.game_room_instances;
create policy "Oda örneklerini giriş yapmışlar görebilir"
  on public.game_room_instances
  for select
  to authenticated
  using (true);

revoke select on public.game_room_instances from anon, public;
grant select on public.game_room_instances to authenticated;

-- Tuning anon yazma yok; anon SELECT kaldır (authenticated yeter)
drop policy if exists "room_game_tuning_select_anon" on public.room_game_tuning;
revoke select on public.room_game_tuning from anon;

do $$
begin
  if to_regclass('public.bot_tuning') is not null then
    execute 'drop policy if exists "bot_tuning_select_anon" on public.bot_tuning';
    execute 'revoke select on public.bot_tuning from anon';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 4) get_admin_analytics — admin exclusion email yerine _admin_user_ids
-- -----------------------------------------------------------------------------

create or replace function public.get_admin_analytics(p_window text default 'all')
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window text := lower(coalesce(nullif(trim(p_window), ''), 'all'));
  v_since timestamptz := public._analytics_window_start(v_window);
  v_result json;
begin
  perform public._require_admin();

  update public.analytics_play_sessions
  set
    ended_at = started_at + interval '6 hours',
    duration_seconds = 21600
  where ended_at is null
    and started_at < timezone('utc', now()) - interval '6 hours';

  with
  admin_ids as (
    select uid as id from public._admin_user_ids() as uid
  ),
  login_event_users as (
    select distinct l.user_id
    from public.analytics_login_events l
    where l.user_id not in (select id from admin_ids)
      and (v_since is null or l.created_at >= v_since)
  ),
  auth_login_users as (
    select u.id as user_id
    from auth.users u
    where u.id not in (select id from admin_ids)
      and (
        v_since is null
        or coalesce(u.last_sign_in_at, u.created_at) >= v_since
      )
  ),
  unique_login_users as (
    select user_id from login_event_users
    union
    select user_id from auth_login_users
  ),
  login_event_rows as (
    select l.user_id, l.created_at
    from public.analytics_login_events l
    where l.user_id not in (select id from admin_ids)
      and (v_since is null or l.created_at >= v_since)
  ),
  member_play_users as (
    select distinct m.user_id
    from public.game_room_members m
    join public.game_room_instances i on i.id = m.room_instance_id
    where m.user_id not in (select id from admin_ids)
      and lower(i.room_type) in ('simple', 'normal', 'elite', 'unique')
      and (v_since is null or m.joined_at >= v_since)
  ),
  leaderboard_play_users as (
    select distinct lb.user_id
    from public.leaderboard lb
    where lb.user_id not in (select id from admin_ids)
      and coalesce(lb.max_mass, 0) > 0
      and (
        v_since is null
        or coalesce(lb.updated_at, lb.created_at) >= v_since
      )
  ),
  winner_play_users as (
    select p.id as user_id
    from public.profiles p
    where p.id not in (select id from admin_ids)
      and coalesce(p.games_won, 0) > 0
      and (v_since is null or p.updated_at >= v_since)
  ),
  tracked_play as (
    select
      p.user_id,
      lower(p.room_type) as room_type,
      p.started_at,
      p.ended_at,
      coalesce(
        p.duration_seconds,
        greatest(
          0,
          least(
            21600,
            floor(
              extract(
                epoch from (
                  coalesce(p.ended_at, timezone('utc', now())) - p.started_at
                )
              )
            )::int
          )
        )
      ) as duration_seconds
    from public.analytics_play_sessions p
    where p.user_id not in (select id from admin_ids)
      and (v_since is null or p.started_at >= v_since)
  ),
  member_play as (
    select
      m.user_id,
      lower(i.room_type) as room_type,
      m.joined_at as started_at,
      m.left_at as ended_at,
      greatest(
        0,
        least(
          21600,
          floor(
            extract(
              epoch from (
                coalesce(m.left_at, timezone('utc', now())) - m.joined_at
              )
            )
          )::int
        )
      ) as duration_seconds
    from public.game_room_members m
    join public.game_room_instances i on i.id = m.room_instance_id
    where m.user_id not in (select id from admin_ids)
      and lower(i.room_type) in ('simple', 'normal', 'elite', 'unique')
      and (v_since is null or m.joined_at >= v_since)
      and not exists (
        select 1
        from public.analytics_play_sessions ap
        where ap.user_id = m.user_id
          and lower(ap.room_type) = lower(i.room_type)
          and abs(extract(epoch from (ap.started_at - m.joined_at))) < 180
      )
  ),
  all_play as (
    select * from tracked_play
    union all
    select * from member_play
  ),
  unique_played_users as (
    select user_id from tracked_play
    union
    select user_id from member_play_users
    union
    select user_id from leaderboard_play_users
    union
    select user_id from winner_play_users
  ),
  diamond_base as (
    select
      d.user_id,
      lower(d.room_type) as room_type,
      d.delta,
      d.placement,
      d.eliminated,
      d.created_at
    from public.analytics_diamond_events d
    where d.user_id not in (select id from admin_ids)
      and (v_since is null or d.created_at >= v_since)
  ),
  totals as (
    select
      (select count(*)::int from unique_login_users) as unique_logins,
      (select count(*)::int from login_event_rows) as total_logins,
      (select count(*)::int from unique_played_users) as unique_players_played,
      (select count(*)::int from all_play) as matches_played,
      (select coalesce(sum(duration_seconds), 0)::bigint from all_play) as total_play_seconds,
      (select count(*)::int from diamond_base where placement = 1) as matches_won,
      (select coalesce(sum(greatest(delta, 0)), 0)::bigint from diamond_base) as diamonds_earned,
      (select coalesce(sum(greatest(-delta, 0)), 0)::bigint from diamond_base) as diamonds_lost,
      (select coalesce(sum(delta), 0)::bigint from diamond_base) as net_diamonds
  ),
  room_types as (
    select unnest(array['simple', 'normal', 'elite', 'unique']) as room_type
  ),
  by_universe as (
    select
      rt.room_type,
      coalesce((
        select count(*)::int
        from (
          select ap.user_id
          from all_play ap
          where ap.room_type = rt.room_type
          union
          select m.user_id
          from public.game_room_members m
          join public.game_room_instances i on i.id = m.room_instance_id
          where m.user_id not in (select id from admin_ids)
            and lower(i.room_type) = rt.room_type
            and (v_since is null or m.joined_at >= v_since)
          union
          select lb.user_id
          from public.leaderboard lb
          where lb.user_id not in (select id from admin_ids)
            and coalesce(lb.max_mass, 0) > 0
            and lower(coalesce(lb.room_type, '')) = rt.room_type
            and (
              v_since is null
              or coalesce(lb.updated_at, lb.created_at) >= v_since
            )
        ) u
      ), 0) as unique_players,
      coalesce((
        select count(*)::int
        from all_play ap
        where ap.room_type = rt.room_type
      ), 0) as matches,
      coalesce((
        select sum(ap.duration_seconds)::bigint
        from all_play ap
        where ap.room_type = rt.room_type
      ), 0) as play_seconds,
      coalesce((
        select sum(greatest(db.delta, 0))::bigint
        from diamond_base db
        where db.room_type = rt.room_type
      ), 0) as diamonds_earned,
      coalesce((
        select sum(greatest(-db.delta, 0))::bigint
        from diamond_base db
        where db.room_type = rt.room_type
      ), 0) as diamonds_lost,
      coalesce((
        select sum(db.delta)::bigint
        from diamond_base db
        where db.room_type = rt.room_type
      ), 0) as net_diamonds,
      coalesce((
        select count(*)::int
        from diamond_base db
        where db.room_type = rt.room_type
          and db.placement = 1
      ), 0) as wins,
      coalesce((
        select count(*)::int
        from diamond_base db
        where db.room_type = rt.room_type
          and db.eliminated
      ), 0) as eliminations,
      coalesce((
        select round(avg(ap.duration_seconds)::numeric, 1)
        from all_play ap
        where ap.room_type = rt.room_type
      ), 0) as avg_match_seconds
    from room_types rt
  )
  select json_build_object(
    'window', v_window,
    'since', v_since,
    'unique_logins', t.unique_logins,
    'total_logins', t.total_logins,
    'unique_players_played', t.unique_players_played,
    'matches_played', t.matches_played,
    'matches_won', t.matches_won,
    'total_play_seconds', t.total_play_seconds,
    'avg_play_seconds_per_match', case
      when t.matches_played > 0
        then round((t.total_play_seconds::numeric / t.matches_played), 1)
      else 0
    end,
    'avg_play_seconds_per_player', case
      when t.unique_players_played > 0
        then round((t.total_play_seconds::numeric / t.unique_players_played), 1)
      else 0
    end,
    'diamonds_earned', t.diamonds_earned,
    'diamonds_lost', t.diamonds_lost,
    'net_diamonds', t.net_diamonds,
    'diamonds_held', (
      select coalesce(sum(p.diamonds), 0)::bigint
      from public.profiles p
      where p.id not in (select id from admin_ids)
    ),
    'registered_players', (
      select count(*)::int
      from public.profiles p
      where p.id not in (select id from admin_ids)
    ),
    'by_universe', coalesce((
      select json_agg(
        json_build_object(
          'room_type', bu.room_type,
          'unique_players', bu.unique_players,
          'matches', bu.matches,
          'play_seconds', bu.play_seconds,
          'diamonds_earned', bu.diamonds_earned,
          'diamonds_lost', bu.diamonds_lost,
          'net_diamonds', bu.net_diamonds,
          'wins', bu.wins,
          'eliminations', bu.eliminations,
          'avg_match_seconds', bu.avg_match_seconds
        )
        order by array_position(
          array['simple', 'normal', 'elite', 'unique'],
          bu.room_type
        )
      )
      from by_universe bu
    ), '[]'::json)
  )
  into v_result
  from totals t;

  return coalesce(v_result, '{}'::json);
end;
$$;

revoke all on function public.get_admin_analytics(text) from public, anon;
grant execute on function public.get_admin_analytics(text) to authenticated;
