-- =============================================================================
-- Quasar.io — Fix admin_mint_sim_player username collisions
-- Symptom: mint failed: duplicate key "profiles_username_lower_key"
-- (HcSim001 / Sim001 already exist from prior Arena / load tests)
-- Safe to re-run.
-- =============================================================================

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
  v_base text;
  v_hash text;
  v_uid uuid := auth.uid();
  v_jwt_admin boolean := false;
  v_suffix text;
  v_try int := 0;
begin
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

  if v_jwt_admin then
    insert into public.admin_users (user_id)
    values (v_uid)
    on conflict (user_id) do nothing;
  end if;

  v_email := format(
    'sim.%s.%s@quasar.sim.local',
    greatest(1, coalesce(p_index, 1)),
    replace(v_user_id::text, '-', '')
  );
  v_password := format(
    'SimLt_%s_%s',
    greatest(1, coalesce(p_index, 1)),
    substr(replace(gen_random_uuid()::text, '-', ''), 1, 16)
  );

  v_base := left(
    coalesce(
      nullif(trim(p_display_name), ''),
      'Sim' || lpad(greatest(1, coalesce(p_index, 1))::text, 3, '0')
    ),
    12
  );
  v_username := v_base;

  -- Avoid profiles_username_lower_key collisions from prior mints.
  while exists (
    select 1
    from public.profiles p
    where lower(trim(p.username)) = lower(v_username)
  ) loop
    v_try := v_try + 1;
    if v_try > 8 then
      v_username := left(
        'S' || substr(replace(v_user_id::text, '-', ''), 1, 11),
        12
      );
      exit;
    end if;
    v_suffix := substr(
      replace(gen_random_uuid()::text, '-', ''),
      1,
      greatest(3, 12 - char_length(left(v_base, 8)))
    );
    v_username := left(left(v_base, 8) || v_suffix, 12);
  end loop;

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
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email'),
      'is_sim', true
    ),
    jsonb_build_object(
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

  begin
    insert into public.sim_players (user_id, minted_by)
    values (v_user_id, v_uid)
    on conflict (user_id) do nothing;
  exception when undefined_table then
    null;
  end;

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

  begin
    insert into public.sim_mint_secrets (user_id, admin_id, password)
    values (v_user_id, v_uid, v_password)
    on conflict (user_id) do update
    set
      admin_id = excluded.admin_id,
      password = excluded.password,
      created_at = timezone('utc', now()),
      revealed_at = null;
  exception when undefined_table then
    -- Older DBs without one-time secret table: return password inline.
    return json_build_object(
      'user_id', v_user_id,
      'email', v_email,
      'password', v_password,
      'username', v_username
    );
  end;

  return json_build_object(
    'user_id', v_user_id,
    'email', v_email,
    'username', v_username,
    'secret_pending', true
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

comment on function public.admin_mint_sim_player(int, text) is
  'Admin: mint sim auth user + profile; unique username even if HcSim001 already taken.';
