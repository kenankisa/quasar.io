-- =============================================================================
-- Quasar.io — Gold para birimini tamamen kaldır
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Satın alma RPC'sini kaldır
-- -----------------------------------------------------------------------------

drop function if exists public.purchase_cosmetic(text);

-- -----------------------------------------------------------------------------
-- 2) Leaderboard / rank — gold tie-break kaldır
-- -----------------------------------------------------------------------------

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
        order by p.diamonds desc, p.games_won desc, p.updated_at desc nulls last
      ) as rank_pos,
      p.id as user_id,
      coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
      p.diamonds
    from public.profiles p
    where not public._is_admin_user(p.id)
    order by p.diamonds desc, p.games_won desc, p.updated_at desc nulls last
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
          order by diamonds desc, games_won desc, updated_at desc nulls last
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

revoke all on function public.get_global_leaderboard(int) from public, anon;
grant execute on function public.get_global_leaderboard(int) to authenticated;

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
        order by diamonds desc, games_won desc, updated_at desc nulls last
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
-- 3) Profil ekonomi guard — gold kontrolünü kaldır
-- -----------------------------------------------------------------------------

create or replace function public._guard_profile_economy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('quasar.trusted_profile_write', true) = '1' then
    return NEW;
  end if;

  if NEW.diamonds is distinct from OLD.diamonds
     or NEW.games_won is distinct from OLD.games_won
     or NEW.active_skin is distinct from OLD.active_skin
     or NEW.peak_diamonds is distinct from OLD.peak_diamonds
     or NEW.skill_tree is distinct from OLD.skill_tree then
    raise exception 'forbidden_profile_field';
  end if;

  return NEW;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4) Yeni kullanıcı profili — gold yazma yok
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id, username, avatar_url, diamonds, games_won, active_skin, updated_at
  )
  values (
    new.id,
    left(
      trim(
        coalesce(
          new.raw_user_meta_data->>'full_name',
          new.raw_user_meta_data->>'name',
          'Cosmic Void'
        )
      ),
      12
    ),
    new.raw_user_meta_data->>'avatar_url',
    20,
    0,
    'default',
    timezone('utc', now())
  )
  on conflict (id) do nothing;

  insert into public.user_skins (user_id, skin_id)
  values (new.id, 'default')
  on conflict (user_id, skin_id) do nothing;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5) Katalog fiyat kolonu + profiles.gold
-- -----------------------------------------------------------------------------

alter table public.cosmetic_catalog
  drop column if exists price_gold;

alter table public.profiles
  drop column if exists gold;

-- -----------------------------------------------------------------------------
-- 6) Load-test mint / prepare — gold'suz profil INSERT
--    Ghost load-test kullanıyorsanız migration_load_test_players*.sql'i de yenileyin.
-- -----------------------------------------------------------------------------

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
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id, 'authenticated', 'authenticated', v_email, v_hash,
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('is_sim', true, 'full_name', v_username, 'name', v_username),
    timezone('utc', now()), timezone('utc', now()), '', '', '', ''
  );

  begin
    insert into auth.identities (
      provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      v_user_id::text, v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text, 'email', v_email,
        'email_verified', true, 'phone_verified', false
      ),
      'email', timezone('utc', now()), timezone('utc', now()), timezone('utc', now())
    );
  exception when others then
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

  return json_build_object(
    'user_id', v_user_id,
    'email', v_email,
    'password', v_password,
    'username', v_username
  );
exception when others then
  return json_build_object('error', SQLERRM, 'sqlstate', SQLSTATE);
end;
$$;

revoke all on function public.admin_mint_sim_player(int, text) from public, anon;
grant execute on function public.admin_mint_sim_player(int, text) to authenticated;

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
  v_name text;
  v_ok boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select u.email, u.raw_user_meta_data
  into v_email, v_meta
  from auth.users u
  where u.id = v_uid;

  if not found then
    raise exception 'not authenticated';
  end if;

  -- Yalnızca mint edilmiş sim hesaplar (anonymous yolu kapalı).
  v_ok :=
    coalesce(v_meta->>'is_sim', '') = 'true'
    or coalesce(v_email, '') like 'sim.%@quasar.sim.local'
    or coalesce(v_email, '') like 'sim.%@example.com';

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

notify pgrst, 'reload schema';
