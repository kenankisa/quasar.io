-- =============================================================================
-- Quasar.io — Yönetici yük testi (sahte eşzamanlı oyuncular)
-- Her sahte oyuncu: ayrı auth.users + profile + device_id oturumu + oda üyeliği.
-- Canlı sayaçlar / matchmaking bunları gerçek oyuncu gibi görür.
-- SQL Editor'da çalıştırın (önceki migration'lardan sonra).
-- =============================================================================

create table if not exists public.load_test_players (
  user_id uuid primary key references auth.users (id) on delete cascade,
  device_id text not null,
  room_type text not null,
  room_instance_id uuid references public.game_room_instances (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint load_test_players_room_type_check
    check (room_type in ('normal', 'elite', 'unique'))
);

create index if not exists load_test_players_room_idx
  on public.load_test_players (room_type, room_instance_id);

alter table public.load_test_players enable row level security;
revoke all on public.load_test_players from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Yardımcı: yük testi kullanıcısı mı?
-- -----------------------------------------------------------------------------

create or replace function public._is_load_test_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.load_test_players l where l.user_id = p_user_id
  );
$$;

revoke all on function public._is_load_test_user(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Kayıtlı oyuncu istatistiklerinden yük testi kullanıcılarını çıkar
-- -----------------------------------------------------------------------------

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
  where not public._is_admin_user(p.id)
    and not public._is_load_test_user(p.id);

  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_winners
  from (
    select
      coalesce(nullif(trim(username), ''), '—') as username,
      games_won,
      diamonds
    from public.profiles p
    where not public._is_admin_user(p.id)
      and not public._is_load_test_user(p.id)
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

revoke all on function public.get_admin_live_player_stats() from public, anon;
grant execute on function public.get_admin_live_player_stats() to authenticated;

-- -----------------------------------------------------------------------------
-- Tek kullanıcıyı odaya yerleştir (join_game_room mantığı, auth.uid bağımsız)
-- -----------------------------------------------------------------------------

create or replace function public._load_test_join_room(
  p_user_id uuid,
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
  v_stale_before timestamptz := timezone('utc', now()) - interval '3 minutes';
begin
  if v_room_type not in ('normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

  -- Bayat üyelikleri kapat
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
    and gri.real_player_count < 10
    and coalesce(gri.updated_at, gri.created_at) >= v_stale_before
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

  -- Zaten aktif üyeyse önce çıkar
  update public.game_room_members
  set left_at = timezone('utc', now())
  where user_id = p_user_id
    and left_at is null;

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, p_user_id);

  update public.game_room_instances
  set
    real_player_count = real_player_count + 1,
    updated_at = timezone('utc', now())
  where id = v_room.id
  returning * into v_room;

  return v_room.id;
end;
$$;

revoke all on function public._load_test_join_room(uuid, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Tek sahte auth kullanıcısı oluştur
-- -----------------------------------------------------------------------------

create or replace function public._load_test_create_auth_user(
  p_index int
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_user_id uuid := gen_random_uuid();
  v_email text := format(
    'loadtest.%s@loadtest.local',
    replace(v_user_id::text, '-', '')
  );
  v_username text := left(
    'LT' || substr(replace(v_user_id::text, '-', ''), 1, 10),
    12
  );
  v_password text;
begin
  begin
    v_password := extensions.crypt(
      gen_random_uuid()::text,
      extensions.gen_salt('bf')
    );
  exception when undefined_function then
    v_password := crypt(gen_random_uuid()::text, gen_salt('bf'));
  end;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    v_password,
    timezone('utc', now()),
    '{"provider":"email","providers":["email"],"is_load_test":true}'::jsonb,
    jsonb_build_object(
      'full_name', v_username,
      'name', v_username,
      'is_load_test', true
    ),
    timezone('utc', now()),
    timezone('utc', now()),
    '',
    '',
    '',
    ''
  );

  begin
    insert into auth.identities (
      provider_id,
      user_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) values (
      v_user_id::text,
      v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now())
    );
  exception when others then
    null;
  end;

  insert into public.profiles (
    id,
    username,
    diamonds,
    games_won,
    active_skin,
    updated_at
  ) values (
    v_user_id,
    v_username,
    500,
    1,
    'default',
    timezone('utc', now())
  )
  on conflict (id) do update
  set
    username = excluded.username,
    diamonds = greatest(public.profiles.diamonds, 500),
    games_won = greatest(public.profiles.games_won, 1),
    updated_at = timezone('utc', now());

  return v_user_id;
exception when others then
  raise exception 'load_test_create_user_failed (%) : %', p_index, SQLERRM
    using errcode = 'P0001';
end;
$$;

revoke all on function public._load_test_create_auth_user(int) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Durum
-- -----------------------------------------------------------------------------

create or replace function public.admin_load_test_status()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active int;
  v_by_room json;
begin
  perform public._require_admin();

  select count(*)::int into v_active from public.load_test_players;

  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_by_room
  from (
    select
      room_type,
      count(*)::int as players,
      count(distinct room_instance_id)::int as rooms
    from public.load_test_players
    group by room_type
    order by room_type
  ) t;

  return json_build_object(
    'active_players', coalesce(v_active, 0),
    'by_room', v_by_room,
    'max_players', 100
  );
end;
$$;

revoke all on function public.admin_load_test_status() from public, anon;
grant execute on function public.admin_load_test_status() to authenticated;

-- -----------------------------------------------------------------------------
-- Heartbeat — oturum + oda bayat kapanmasını engeller
-- -----------------------------------------------------------------------------

create or replace function public.admin_heartbeat_load_test()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessions int;
  v_rooms int;
begin
  perform public._require_admin();

  update public.player_active_sessions s
  set last_heartbeat_at = timezone('utc', now())
  from public.load_test_players l
  where s.user_id = l.user_id;
  get diagnostics v_sessions = row_count;

  update public.game_room_instances gri
  set updated_at = timezone('utc', now())
  where gri.id in (
    select distinct room_instance_id
    from public.load_test_players
    where room_instance_id is not null
  )
  and gri.status = 'open';
  get diagnostics v_rooms = row_count;

  return json_build_object(
    'sessions_touched', coalesce(v_sessions, 0),
    'rooms_touched', coalesce(v_rooms, 0),
    'active_players', (select count(*)::int from public.load_test_players)
  );
end;
$$;

revoke all on function public.admin_heartbeat_load_test() from public, anon;
grant execute on function public.admin_heartbeat_load_test() to authenticated;

-- -----------------------------------------------------------------------------
-- Durdur — üyeliği bırak, oturumu sil, auth kullanıcılarını temizle
-- -----------------------------------------------------------------------------

create or replace function public.admin_stop_load_test()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_ids uuid[];
  v_count int;
  v_uid uuid;
  v_room_id uuid;
begin
  perform public._require_admin();

  select coalesce(array_agg(user_id), '{}'::uuid[])
  into v_user_ids
  from public.load_test_players;

  v_count := coalesce(cardinality(v_user_ids), 0);
  if v_count = 0 then
    return json_build_object('stopped', 0);
  end if;

  foreach v_uid in array v_user_ids
  loop
    select room_instance_id into v_room_id
    from public.load_test_players
    where user_id = v_uid;

    update public.game_room_members
    set left_at = timezone('utc', now())
    where user_id = v_uid
      and left_at is null;

    if v_room_id is not null then
      update public.game_room_instances gri
      set
        real_player_count = greatest(
          0,
          (
            select count(*)::int
            from public.game_room_members grm
            where grm.room_instance_id = gri.id
              and grm.left_at is null
          )
        ),
        updated_at = timezone('utc', now())
      where gri.id = v_room_id;
    end if;
  end loop;

  delete from public.player_active_sessions
  where user_id = any (v_user_ids);

  delete from public.load_test_players
  where user_id = any (v_user_ids);

  delete from auth.identities
  where user_id = any (v_user_ids);

  delete from auth.users
  where id = any (v_user_ids);

  return json_build_object('stopped', v_count);
end;
$$;

revoke all on function public.admin_stop_load_test() from public, anon;
grant execute on function public.admin_stop_load_test() to authenticated;

-- -----------------------------------------------------------------------------
-- Başlat — N sahte oyuncu (önce mevcut testi temizler)
-- -----------------------------------------------------------------------------

create or replace function public.admin_start_load_test(
  p_count int,
  p_room_type text default 'normal'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := greatest(1, least(coalesce(p_count, 0), 100));
  v_room_type text := lower(trim(coalesce(p_room_type, 'normal')));
  v_i int;
  v_user_id uuid;
  v_device_id text;
  v_room_id uuid;
  v_created int := 0;
  v_rooms int;
begin
  perform public._require_admin();

  if v_room_type not in ('normal', 'elite', 'unique') then
    return json_build_object('error', 'invalid_room_type', 'started', 0);
  end if;

  -- Orphan temizliği (varsa fix migration; yoksa stop)
  begin
    perform public._load_test_purge_orphan_users();
  exception when undefined_function then
    perform public.admin_stop_load_test();
  end;

  for v_i in 1..v_count
  loop
    v_user_id := public._load_test_create_auth_user(v_i);
    v_device_id := format('loadtest_%s', replace(v_user_id::text, '-', ''));
    v_room_id := public._load_test_join_room(v_user_id, v_room_type);

    insert into public.player_active_sessions (
      user_id,
      device_id,
      room_type,
      started_at,
      last_heartbeat_at
    ) values (
      v_user_id,
      v_device_id,
      v_room_type,
      timezone('utc', now()),
      timezone('utc', now())
    )
    on conflict (user_id) do update
    set
      device_id = excluded.device_id,
      room_type = excluded.room_type,
      started_at = excluded.started_at,
      last_heartbeat_at = excluded.last_heartbeat_at;

    insert into public.load_test_players (
      user_id,
      device_id,
      room_type,
      room_instance_id
    ) values (
      v_user_id,
      v_device_id,
      v_room_type,
      v_room_id
    );

    v_created := v_created + 1;
  end loop;

  select count(distinct room_instance_id)::int
  into v_rooms
  from public.load_test_players;

  return json_build_object(
    'started', v_created,
    'room_type', v_room_type,
    'rooms_used', coalesce(v_rooms, 0),
    'active_players', (select count(*)::int from public.load_test_players)
  );
exception when others then
  begin
    perform public._load_test_purge_orphan_users();
  exception when others then
    null;
  end;
  return json_build_object(
    'error', SQLERRM,
    'started', 0,
    'active_players', 0
  );
end;
$$;

revoke all on function public.admin_start_load_test(int, text) from public, anon;
grant execute on function public.admin_start_load_test(int, text) to authenticated;
