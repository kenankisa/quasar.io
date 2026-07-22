-- =============================================================================
-- Quasar.io — Yönetim paneli geçmiş istatistikleri
-- SQL Editor'da çalıştırın (önceki session / rooms / match_rewards migration'larından sonra).
-- Admin: admin_users + app_metadata.role (_is_admin_user). Email hardcode yok.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Olay tabloları
-- -----------------------------------------------------------------------------

create table if not exists public.analytics_login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists analytics_login_events_created_idx
  on public.analytics_login_events (created_at desc);

create index if not exists analytics_login_events_user_created_idx
  on public.analytics_login_events (user_id, created_at desc);

create table if not exists public.analytics_play_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  room_type text not null,
  room_instance_id uuid,
  started_at timestamptz not null default timezone('utc', now()),
  ended_at timestamptz,
  duration_seconds integer
);

create index if not exists analytics_play_sessions_started_idx
  on public.analytics_play_sessions (started_at desc);

create index if not exists analytics_play_sessions_room_started_idx
  on public.analytics_play_sessions (room_type, started_at desc);

create index if not exists analytics_play_sessions_open_idx
  on public.analytics_play_sessions (user_id)
  where ended_at is null;

create table if not exists public.analytics_diamond_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  room_type text not null,
  delta integer not null,
  placement integer,
  eliminated boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists analytics_diamond_events_created_idx
  on public.analytics_diamond_events (created_at desc);

create index if not exists analytics_diamond_events_room_created_idx
  on public.analytics_diamond_events (room_type, created_at desc);

alter table public.analytics_login_events enable row level security;
alter table public.analytics_play_sessions enable row level security;
alter table public.analytics_diamond_events enable row level security;

-- Doğrudan client okuma yok — yalnızca admin RPC.
drop policy if exists "analytics_login_no_direct" on public.analytics_login_events;
drop policy if exists "analytics_play_no_direct" on public.analytics_play_sessions;
drop policy if exists "analytics_diamond_no_direct" on public.analytics_diamond_events;

-- -----------------------------------------------------------------------------
-- 2) Yardımcılar
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

create or replace function public._analytics_window_start(p_window text)
returns timestamptz
language plpgsql
stable
as $$
declare
  v_window text := lower(coalesce(nullif(trim(p_window), ''), 'all'));
begin
  return case v_window
    when '1h' then timezone('utc', now()) - interval '1 hour'
    when '1d' then timezone('utc', now()) - interval '1 day'
    when '7d' then timezone('utc', now()) - interval '7 days'
    when '30d' then timezone('utc', now()) - interval '30 days'
    else null
  end;
end;
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

-- Açık eğitim oturumlarını kapat (max 6 saat güvenlik tavanı).
create or replace function public._close_open_play_sessions(
  p_user_id uuid,
  p_room_type text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
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
    and (p_room_type is null or room_type = p_room_type);
end;
$$;

-- -----------------------------------------------------------------------------
-- 3) claim_player_session — yeni giriş olayını kaydet
-- -----------------------------------------------------------------------------

create or replace function public.claim_player_session(
  p_device_id text,
  p_room_type text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_device_id text := nullif(trim(p_device_id), '');
  v_room_type text := nullif(lower(trim(p_room_type)), '');
  v_session public.player_active_sessions%rowtype;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_device_id is null then
    raise exception 'invalid device_id';
  end if;

  perform public._purge_stale_player_sessions();

  select *
  into v_session
  from public.player_active_sessions
  where user_id = v_user_id
  for update;

  if found then
    if v_session.device_id <> v_device_id then
      raise exception 'player_already_active';
    end if;

    update public.player_active_sessions
    set
      room_type = coalesce(v_room_type, room_type),
      last_heartbeat_at = timezone('utc', now())
    where user_id = v_user_id;
    return;
  end if;

  insert into public.player_active_sessions (
    user_id,
    device_id,
    room_type,
    started_at,
    last_heartbeat_at
  )
  values (
    v_user_id,
    v_device_id,
    v_room_type,
    timezone('utc', now()),
    timezone('utc', now())
  );

  if not public._is_admin_user(v_user_id) then
    insert into public.analytics_login_events (user_id)
    values (v_user_id);
  end if;
end;
$$;

grant execute on function public.claim_player_session(text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Elmas defteri — profiles trigger (tüm elmas değişimleri)
-- -----------------------------------------------------------------------------

create or replace function public._analytics_on_profile_diamonds()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta int;
  v_room text;
  v_placement int;
  v_eliminated boolean;
begin
  if tg_op <> 'UPDATE' then
    return NEW;
  end if;

  v_delta := coalesce(NEW.diamonds, 0) - coalesce(OLD.diamonds, 0);
  if v_delta = 0 then
    return NEW;
  end if;

  -- Admin test hesabı ekonomiye karışmasın.
  if public._is_admin_user(NEW.id) then
    return NEW;
  end if;

  v_room := lower(nullif(trim(current_setting('quasar.analytics_room_type', true)), ''));
  if v_room is null then
    v_room := 'other';
  end if;

  begin
    v_placement := nullif(current_setting('quasar.analytics_placement', true), '')::int;
  exception
    when others then
      v_placement := null;
  end;

  begin
    v_eliminated := coalesce(
      nullif(current_setting('quasar.analytics_eliminated', true), '')::boolean,
      false
    );
  exception
    when others then
      v_eliminated := false;
  end;

  insert into public.analytics_diamond_events (
    user_id,
    room_type,
    delta,
    placement,
    eliminated
  )
  values (
    NEW.id,
    v_room,
    v_delta,
    v_placement,
    v_eliminated
  );

  return NEW;
end;
$$;

drop trigger if exists trg_analytics_profile_diamonds on public.profiles;
create trigger trg_analytics_profile_diamonds
  after update of diamonds on public.profiles
  for each row
  execute function public._analytics_on_profile_diamonds();

-- -----------------------------------------------------------------------------
-- 4b) apply_match_result — elmas güncelle + oturum bağlamı (trigger yazar)
-- -----------------------------------------------------------------------------

create or replace function public.apply_match_result(
  p_room_type text default 'normal',
  p_placement int default null,
  p_eliminated boolean default false
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta int := 0;
  v_won int := 0;
  v_new_diamonds int;
  v_room text := lower(coalesce(p_room_type, 'normal'));
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if coalesce(p_eliminated, false) then
    v_delta := case v_room
      when 'simple' then 0
      when 'elite' then -2
      when 'unique' then -3
      else -1
    end;
  else
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
    where id = v_user_id;
    return coalesce(v_new_diamonds, 0);
  end if;

  -- Trigger'ın evren / yerleştirme bilgisini yazması için (transaction-local).
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config(
    'quasar.analytics_placement',
    case
      when coalesce(p_eliminated, false) then ''
      else coalesce(p_placement::text, '')
    end,
    true
  );
  perform set_config(
    'quasar.analytics_eliminated',
    case when coalesce(p_eliminated, false) then 'true' else 'false' end,
    true
  );

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    games_won = games_won + v_won,
    updated_at = timezone('utc', now())
  where id = v_user_id
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

grant execute on function public.apply_match_result(text, int, boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Eğitim evreni oyun süresi (client RPC)
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

  -- Aynı kullanıcının açık oturumunu kapat (çift kayıt engeli).
  perform public._close_open_play_sessions(v_user_id, null);

  insert into public.analytics_play_sessions (user_id, room_type)
  values (v_user_id, v_room)
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.analytics_begin_play_session(text) to authenticated;

create or replace function public.analytics_end_play_session(p_room_type text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room text := nullif(lower(trim(p_room_type)), '');
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  perform public._close_open_play_sessions(v_user_id, v_room);
end;
$$;

grant execute on function public.analytics_end_play_session(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) Admin agregasyon RPC
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

  -- Bayat açık eğitim oturumlarını kapat (6 saatten eski).
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
  -- Uygulamaya giriş yapan farklı oyuncular:
  -- 1) analytics_login_events (oturum claim)
  -- 2) auth.users last_sign_in / created (yedek — eski girişler)
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
  -- Oynayan farklı oyuncular:
  -- tracker + üyelik + liderlik tablosu + en az 1 galibiyet (eski maçlar için geriye dönük)
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
      -- Tracker kaydı yoksa geçmiş üyeliklerden tamamla (oda recycle silmeden önce)
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
    -- Oyuncuların şu an elinde tuttuğu toplam elmas (anlık stok; zaman penceresinden bağımsız).
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

revoke all on function public.get_admin_analytics(text) from public;
grant execute on function public.get_admin_analytics(text) to authenticated;
