-- =============================================================================
-- Quasar.io — Yük testi düzeltmesi (auth kullanıcı oluşturma + hata mesajı)
-- SQL Editor'da migration_load_test_players.sql sonrası çalıştırın.
-- =============================================================================

-- Orphan load-test hesaplarını temizle (önceki başarısız denemeler)
create or replace function public._load_test_purge_orphan_users()
returns int
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ids uuid[];
  v_n int := 0;
begin
  select coalesce(array_agg(u.id), '{}'::uuid[])
  into v_ids
  from auth.users u
  where coalesce(u.raw_app_meta_data->>'is_load_test', '') = 'true'
     or u.email like 'loadtest%@quasar.loadtest'
     or u.email like 'loadtest.%@loadtest.local';

  v_n := coalesce(cardinality(v_ids), 0);
  if v_n = 0 then
    return 0;
  end if;

  delete from public.player_active_sessions where user_id = any (v_ids);
  delete from public.load_test_players where user_id = any (v_ids);

  update public.game_room_members
  set left_at = timezone('utc', now())
  where user_id = any (v_ids)
    and left_at is null;

  delete from auth.identities where user_id = any (v_ids);
  delete from auth.users where id = any (v_ids);

  -- Oda sayaçlarını üyelerden yeniden hesapla
  update public.game_room_instances gri
  set
    real_player_count = coalesce((
      select count(*)::int
      from public.game_room_members grm
      where grm.room_instance_id = gri.id
        and grm.left_at is null
    ), 0),
    updated_at = timezone('utc', now())
  where gri.status = 'open';

  return v_n;
end;
$$;

revoke all on function public._load_test_purge_orphan_users() from public, anon, authenticated;

-- Daha dayanıklı kullanıcı oluşturma (benzersiz isim, identities opsiyonel)
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

  -- identities bazı projelerde zorunlu/şema farklı — best effort
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
    -- Kimlik satırı olmadan da oturum/oda testi çalışır
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

create or replace function public.admin_stop_load_test()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_purged int;
begin
  perform public._require_admin();
  v_purged := public._load_test_purge_orphan_users();
  return json_build_object('stopped', coalesce(v_purged, 0));
end;
$$;

revoke all on function public.admin_stop_load_test() from public, anon;
grant execute on function public.admin_stop_load_test() to authenticated;

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
    return json_build_object(
      'error', 'invalid_room_type',
      'started', 0
    );
  end if;

  perform public._load_test_purge_orphan_users();

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
  -- Kısmi oluşturulanları temizle
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
