-- =============================================================================
-- Quasar.io — Sim hesapları admin ile üret (Anonymous / confirm email gerekmez)
-- SQL Editor'da migration_load_test_sim_clients.sql sonrası çalıştırın.
--
-- "forbidden" alırsan (e-postanı değiştir):
--   insert into public.admin_users (user_id)
--   select id from auth.users where lower(email) = lower('SENIN@EMAIL.com')
--   on conflict do nothing;
--   update auth.users
--   set raw_app_meta_data =
--     coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
--   where lower(email) = lower('SENIN@EMAIL.com');
-- =============================================================================

-- JWT'de role=admin olanları admin_users ile senkron tut
insert into public.admin_users (user_id)
select u.id
from auth.users u
where coalesce(u.raw_app_meta_data->>'role', '') = 'admin'
on conflict (user_id) do nothing;

create or replace function public.admin_mint_sim_player(
  p_index int default 1,
  p_display_name text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_user_id uuid := gen_random_uuid();
  v_email text;
  v_password text;
  v_username text;
  v_hash text;
  v_uid uuid := auth.uid();
  v_jwt_admin boolean := false;
begin
  -- Panel ile birebir aynı: JWT role=admin VEYA admin_users / raw_app_meta_data
  if v_uid is null then
    return json_build_object('error', 'not authenticated');
  end if;

  v_jwt_admin :=
    coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin';

  if not v_jwt_admin and not public._is_admin_user(v_uid) then
    return json_build_object(
      'error', 'forbidden',
      'hint', 'admin_users veya app_metadata.role=admin gerekli',
      'uid', v_uid
    );
  end if;

  -- JWT ile geçmişse tabloya da yaz (sonraki _is_admin_user çağrıları için)
  if v_jwt_admin then
    insert into public.admin_users (user_id)
    values (v_uid)
    on conflict (user_id) do nothing;
  end if;

  v_email := format(
    'sim.%s.%s@example.com',
    greatest(1, coalesce(p_index, 1)),
    replace(v_user_id::text, '-', '')
  );
  v_password := format(
    'SimLt_%s_%s',
    greatest(1, coalesce(p_index, 1)),
    substr(replace(gen_random_uuid()::text, '-', ''), 1, 16)
  );
  v_username := left(
    coalesce(
      nullif(trim(p_display_name), ''),
      'Sim' || lpad(greatest(1, coalesce(p_index, 1))::text, 3, '0')
    ),
    12
  );

  begin
    v_hash := extensions.crypt(v_password, extensions.gen_salt('bf'));
  exception when undefined_function then
    v_hash := crypt(v_password, gen_salt('bf'));
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
    v_hash,
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'is_sim', true,
      'full_name', v_username,
      'name', v_username
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

  -- handle_new_user önce profil açar; economy trigger diamonds/games_won
  -- update'ini engeller → trusted write şart
  perform public._allow_trusted_profile_write();

  insert into public.profiles (
    id, username, diamonds, games_won, active_skin, updated_at
  ) values (
    v_user_id, v_username, 500, 1, 'default', timezone('utc', now())
  )
  on conflict (id) do update
  set
    username = excluded.username,
    diamonds = greatest(public.profiles.diamonds, 500),
    games_won = greatest(public.profiles.games_won, 1),
    updated_at = timezone('utc', now());

  return json_build_object(
    'user_id', v_user_id,
    'email', v_email,
    'password', v_password,
    'username', v_username
  );
exception when others then
  return json_build_object(
    'error', SQLERRM,
    'sqlstate', SQLSTATE
  );
end;
$$;

revoke all on function public.admin_mint_sim_player(int, text) from public, anon;
grant execute on function public.admin_mint_sim_player(int, text) to authenticated;

-- prepare: example.com sim maillerini de kabul et
create or replace function public.prepare_simulated_player(
  p_display_name text default null
)
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_meta jsonb;
  v_app jsonb;
  v_name text;
  v_ok boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select u.email, u.raw_user_meta_data, u.raw_app_meta_data
  into v_email, v_meta, v_app
  from auth.users u
  where u.id = v_uid;

  if not found then
    raise exception 'not authenticated';
  end if;

  v_ok :=
    coalesce(v_meta->>'is_sim', '') = 'true'
    or coalesce(v_email, '') like 'sim.%@quasar.sim.local'
    or coalesce(v_email, '') like 'sim.%@example.com'
    or coalesce(v_app->>'provider', '') = 'anonymous'
    or coalesce(v_app->'providers', '[]'::jsonb) ? 'anonymous';

  if not v_ok then
    raise exception 'forbidden';
  end if;

  v_name := left(
    coalesce(
      nullif(trim(p_display_name), ''),
      nullif(trim(v_meta->>'full_name'), ''),
      'Sim' || substr(replace(v_uid::text, '-', ''), 1, 8)
    ),
    12
  );

  if exists (
    select 1 from public.profiles p
    where lower(trim(p.username)) = lower(v_name)
      and p.id <> v_uid
  ) then
    v_name := left('S' || substr(replace(v_uid::text, '-', ''), 1, 11), 12);
  end if;

  perform public._allow_trusted_profile_write();

  insert into public.profiles (
    id, username, diamonds, games_won, active_skin, updated_at
  ) values (
    v_uid, v_name, 500, 1, 'default', timezone('utc', now())
  )
  on conflict (id) do update
  set
    username = excluded.username,
    diamonds = greatest(public.profiles.diamonds, 500),
    games_won = greatest(public.profiles.games_won, 1),
    updated_at = timezone('utc', now());

  return json_build_object(
    'ok', true,
    'user_id', v_uid,
    'username', v_name
  );
end;
$$;

revoke all on function public.prepare_simulated_player(text) from public, anon;
grant execute on function public.prepare_simulated_player(text) to authenticated;

create or replace function public.admin_cleanup_simulated_players()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ids uuid[];
  v_n int := 0;
begin
  perform public._require_admin();

  select coalesce(array_agg(u.id), '{}'::uuid[])
  into v_ids
  from auth.users u
  where coalesce(u.raw_user_meta_data->>'is_sim', '') = 'true'
     or coalesce(u.email, '') like 'sim.%@quasar.sim.local'
     or coalesce(u.email, '') like 'sim.%@example.com';

  v_n := coalesce(cardinality(v_ids), 0);
  if v_n = 0 then
    return json_build_object('deleted', 0);
  end if;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where user_id = any (v_ids)
    and left_at is null;

  delete from public.player_active_sessions where user_id = any (v_ids);

  begin
    delete from auth.identities where user_id = any (v_ids);
    delete from auth.users where id = any (v_ids);
  exception when others then
    return json_build_object(
      'deleted', 0,
      'error', SQLERRM,
      'candidates', v_n
    );
  end;

  return json_build_object('deleted', v_n);
end;
$$;

revoke all on function public.admin_cleanup_simulated_players() from public, anon;
grant execute on function public.admin_cleanup_simulated_players() to authenticated;
