-- =============================================================================
-- Quasar.io — Medium güvenlik (round 2)
-- 1) Rewarded 2×: client attest + daha uzun min izleme + günlük cap
-- 2) Placement 2/3: oda+nesil başına tek slot
-- 3) _is_admin_user EXECUTE revoke (UUID keşif kapalı)
-- 4) list_sim_load_test_rooms admin-only
-- 5) admin_mint: şifre tek kullanımlık claim tablosuna
-- 6) Admin e-posta seed: app.admin_seed_email (repoda hardcode yok)
-- SQL Editor'da migration_security_medium_fixes.sql / high_anon_sim_mint sonrası.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Rewarded ad — attest + sıkı claim
-- -----------------------------------------------------------------------------

alter table public.match_reward_claims
  add column if not exists ad_double_attested_at timestamptz;

comment on column public.match_reward_claims.ad_double_attested_at is
  'Set by attest_rewarded_match_double after client onUserEarnedReward; required to claim.';

create or replace function public.prepare_rewarded_match_double(
  p_room_type text default 'normal',
  p_room_instance_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_room_row public.game_room_instances%rowtype;
  v_claim public.match_reward_claims%rowtype;
  v_match_gen int;
  v_day_count int;
  v_session uuid := gen_random_uuid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('normal', 'elite', 'unique') then
    raise exception 'ad_double_not_allowed';
  end if;

  if p_room_instance_id is null then
    raise exception 'room_required';
  end if;

  select *
  into v_room_row
  from public.game_room_instances
  where id = p_room_instance_id
  for share;

  if not found then
    raise exception 'room_not_found';
  end if;

  if lower(v_room_row.room_type) <> v_room then
    raise exception 'room_type_mismatch';
  end if;

  v_match_gen := coalesce(v_room_row.match_generation, 1);

  select *
  into v_claim
  from public.match_reward_claims
  where user_id = v_uid
    and room_instance_id = p_room_instance_id
    and match_generation = v_match_gen
    and claim_kind = 'reward'
    and diamond_delta > 0
  for update;

  if not found then
    raise exception 'no_reward_claim';
  end if;

  if v_claim.ad_double_claimed_at is not null then
    raise exception 'already_doubled';
  end if;

  if v_claim.created_at < timezone('utc', now()) - interval '10 minutes' then
    raise exception 'ad_double_expired';
  end if;

  select count(*)::int
  into v_day_count
  from public.match_reward_claims
  where user_id = v_uid
    and ad_double_claimed_at is not null
    and ad_double_claimed_at >= timezone('utc', now()) - interval '24 hours';

  if coalesce(v_day_count, 0) >= 3 then
    raise exception 'ad_double_daily_limit';
  end if;

  if v_claim.ad_double_session_id is not null
     and v_claim.ad_double_prepared_at is not null
     and v_claim.ad_double_prepared_at > timezone('utc', now()) - interval '5 minutes'
     and v_claim.ad_double_attested_at is null then
    return v_claim.ad_double_session_id;
  end if;

  update public.match_reward_claims
  set
    ad_double_session_id = v_session,
    ad_double_prepared_at = timezone('utc', now()),
    ad_double_attested_at = null
  where id = v_claim.id
    and ad_double_claimed_at is null;

  return v_session;
end;
$$;

revoke all on function public.prepare_rewarded_match_double(text, uuid)
  from public, anon;
grant execute on function public.prepare_rewarded_match_double(text, uuid)
  to authenticated;

-- Reklam ödülü callback'inden sonra çağrılır (claim öncesi zorunlu).
create or replace function public.attest_rewarded_match_double(
  p_room_type text default 'normal',
  p_room_instance_id uuid default null,
  p_session_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_room_row public.game_room_instances%rowtype;
  v_claim public.match_reward_claims%rowtype;
  v_match_gen int;
  v_elapsed_sec double precision;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('normal', 'elite', 'unique') then
    raise exception 'ad_double_not_allowed';
  end if;

  if p_room_instance_id is null or p_session_id is null then
    raise exception 'ad_session_required';
  end if;

  select *
  into v_room_row
  from public.game_room_instances
  where id = p_room_instance_id
  for share;

  if not found then
    raise exception 'room_not_found';
  end if;

  if lower(v_room_row.room_type) <> v_room then
    raise exception 'room_type_mismatch';
  end if;

  v_match_gen := coalesce(v_room_row.match_generation, 1);

  select *
  into v_claim
  from public.match_reward_claims
  where user_id = v_uid
    and room_instance_id = p_room_instance_id
    and match_generation = v_match_gen
    and claim_kind = 'reward'
    and diamond_delta > 0
  for update;

  if not found then
    raise exception 'no_reward_claim';
  end if;

  if v_claim.ad_double_claimed_at is not null then
    raise exception 'already_doubled';
  end if;

  if v_claim.ad_double_session_id is distinct from p_session_id then
    raise exception 'ad_session_invalid';
  end if;

  if v_claim.ad_double_prepared_at is null then
    raise exception 'ad_session_invalid';
  end if;

  v_elapsed_sec := extract(
    epoch from (timezone('utc', now()) - v_claim.ad_double_prepared_at)
  );

  if v_elapsed_sec > 300 then
    raise exception 'ad_session_expired';
  end if;

  if v_claim.ad_double_attested_at is not null then
    return true;
  end if;

  update public.match_reward_claims
  set ad_double_attested_at = timezone('utc', now())
  where id = v_claim.id
    and ad_double_claimed_at is null
    and ad_double_session_id = p_session_id;

  return true;
end;
$$;

revoke all on function public.attest_rewarded_match_double(text, uuid, uuid)
  from public, anon;
grant execute on function public.attest_rewarded_match_double(text, uuid, uuid)
  to authenticated;

create or replace function public.claim_rewarded_match_double(
  p_room_type text default 'normal',
  p_room_instance_id uuid default null,
  p_session_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_room_row public.game_room_instances%rowtype;
  v_claim public.match_reward_claims%rowtype;
  v_match_gen int;
  v_day_count int;
  v_bonus int;
  v_new_diamonds int;
  v_elapsed_sec double precision;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('normal', 'elite', 'unique') then
    raise exception 'ad_double_not_allowed';
  end if;

  if p_room_instance_id is null then
    raise exception 'room_required';
  end if;

  if p_session_id is null then
    raise exception 'ad_session_required';
  end if;

  select *
  into v_room_row
  from public.game_room_instances
  where id = p_room_instance_id
  for share;

  if not found then
    raise exception 'room_not_found';
  end if;

  if lower(v_room_row.room_type) <> v_room then
    raise exception 'room_type_mismatch';
  end if;

  v_match_gen := coalesce(v_room_row.match_generation, 1);

  select *
  into v_claim
  from public.match_reward_claims
  where user_id = v_uid
    and room_instance_id = p_room_instance_id
    and match_generation = v_match_gen
    and claim_kind = 'reward'
    and diamond_delta > 0
  for update;

  if not found then
    raise exception 'no_reward_claim';
  end if;

  if v_claim.ad_double_claimed_at is not null then
    raise exception 'already_doubled';
  end if;

  if v_claim.ad_double_session_id is distinct from p_session_id then
    raise exception 'ad_session_invalid';
  end if;

  if v_claim.ad_double_prepared_at is null
     or v_claim.ad_double_attested_at is null then
    raise exception 'ad_not_attested';
  end if;

  v_elapsed_sec := extract(
    epoch from (timezone('utc', now()) - v_claim.ad_double_prepared_at)
  );

  if v_elapsed_sec < 15 then
    raise exception 'ad_watch_too_short';
  end if;

  if v_elapsed_sec > 300 then
    raise exception 'ad_session_expired';
  end if;

  if v_claim.created_at < timezone('utc', now()) - interval '10 minutes' then
    raise exception 'ad_double_expired';
  end if;

  select count(*)::int
  into v_day_count
  from public.match_reward_claims
  where user_id = v_uid
    and ad_double_claimed_at is not null
    and ad_double_claimed_at >= timezone('utc', now()) - interval '24 hours';

  if coalesce(v_day_count, 0) >= 3 then
    raise exception 'ad_double_daily_limit';
  end if;

  v_bonus := v_claim.diamond_delta;

  update public.match_reward_claims
  set
    ad_double_claimed_at = timezone('utc', now()),
    ad_double_session_id = null,
    ad_double_prepared_at = null,
    ad_double_attested_at = null
  where id = v_claim.id
    and ad_double_claimed_at is null
    and ad_double_session_id = p_session_id
    and ad_double_attested_at is not null;

  if not found then
    raise exception 'already_doubled';
  end if;

  perform public._allow_trusted_profile_write();
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config('quasar.analytics_placement', coalesce(v_claim.placement::text, ''), true);
  perform set_config('quasar.analytics_eliminated', 'false', true);

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_bonus),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

revoke all on function public.claim_rewarded_match_double(text, uuid, uuid)
  from public, anon;
grant execute on function public.claim_rewarded_match_double(text, uuid, uuid)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 2) Placement 2 / 3 — maç başına tek slot (1. sıra gibi)
-- -----------------------------------------------------------------------------

create unique index if not exists match_reward_claims_second_place_gen_uidx
  on public.match_reward_claims (room_instance_id, match_generation)
  where claim_kind = 'reward'
    and placement = 2
    and room_instance_id is not null
    and match_generation is not null;

create unique index if not exists match_reward_claims_third_place_gen_uidx
  on public.match_reward_claims (room_instance_id, match_generation)
  where claim_kind = 'reward'
    and placement = 3
    and room_instance_id is not null
    and match_generation is not null;

-- -----------------------------------------------------------------------------
-- 3) _is_admin_user — istemci EXECUTE kapat (RLS table-owner ile çalışır)
-- -----------------------------------------------------------------------------

revoke all on function public._is_admin_user(uuid)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4) list_sim_load_test_rooms — yalnızca admin
-- -----------------------------------------------------------------------------

create or replace function public.list_sim_load_test_rooms()
returns json
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  perform public._require_admin();

  return coalesce(
    (
      select json_agg(row_to_json(t) order by t.players desc, t.instance_number)
      from (
        select
          gri.id as room_instance_id,
          gri.room_type,
          gri.instance_number,
          count(*)::int as players,
          gri.leader_radius,
          gri.status,
          true as is_load_test
        from public.game_room_instances gri
        join public.game_room_members grm
          on grm.room_instance_id = gri.id
         and grm.left_at is null
        join auth.users u on u.id = grm.user_id
        where gri.status = 'open'
          and gri.is_load_test = true
          and (
            coalesce(u.raw_user_meta_data->>'is_sim', '') = 'true'
            or coalesce(u.email, '') like 'sim.%@example.com'
            or coalesce(u.email, '') like 'sim.%@quasar.sim.local'
          )
        group by gri.id, gri.room_type, gri.instance_number, gri.leader_radius, gri.status
      ) t
    ),
    '[]'::json
  );
end;
$$;

revoke all on function public.list_sim_load_test_rooms() from public, anon;
grant execute on function public.list_sim_load_test_rooms() to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Sim mint — şifre tek kullanımlık claim (RPC cevabında plaintext yok)
-- -----------------------------------------------------------------------------

create table if not exists public.sim_mint_secrets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  admin_id uuid not null references auth.users (id) on delete cascade,
  password text not null,
  created_at timestamptz not null default timezone('utc', now()),
  revealed_at timestamptz
);

alter table public.sim_mint_secrets enable row level security;
revoke all on public.sim_mint_secrets from public, anon, authenticated;

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

  insert into public.sim_mint_secrets (user_id, admin_id, password)
  values (v_user_id, v_uid, v_password)
  on conflict (user_id) do update
  set
    admin_id = excluded.admin_id,
    password = excluded.password,
    created_at = timezone('utc', now()),
    revealed_at = null;

  -- Şifre RPC cevabında yok — admin_claim_sim_mint_secret ile bir kez alınır.
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

create or replace function public.admin_claim_sim_mint_secret(p_user_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.sim_mint_secrets%rowtype;
  v_password text;
begin
  perform public._require_admin();

  if p_user_id is null then
    raise exception 'invalid_user';
  end if;

  select * into v_row
  from public.sim_mint_secrets
  where user_id = p_user_id
  for update;

  if not found then
    raise exception 'secret_not_found';
  end if;

  if v_row.admin_id is distinct from v_uid then
    raise exception 'forbidden';
  end if;

  if v_row.revealed_at is not null then
    raise exception 'secret_already_claimed';
  end if;

  if v_row.created_at < timezone('utc', now()) - interval '10 minutes' then
    delete from public.sim_mint_secrets where user_id = p_user_id;
    raise exception 'secret_expired';
  end if;

  v_password := v_row.password;

  update public.sim_mint_secrets
  set
    password = '',
    revealed_at = timezone('utc', now())
  where user_id = p_user_id;

  return json_build_object(
    'user_id', p_user_id,
    'password', v_password
  );
end;
$$;

revoke all on function public.admin_claim_sim_mint_secret(uuid) from public, anon;
grant execute on function public.admin_claim_sim_mint_secret(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) Admin seed — e-posta repoda yok; isteğe bağlı session GUC
--    Kullanım (SQL Editor'da bir kez):
--      select set_config('app.admin_seed_email', 'owner@example.com', false);
--      -- sonra bu bloğu çalıştır / migration'ı re-run et
-- -----------------------------------------------------------------------------

do $$
declare
  v_email text := nullif(
    trim(lower(coalesce(current_setting('app.admin_seed_email', true), ''))),
    ''
  );
begin
  if v_email is null then
    raise notice 'admin_seed_skipped: set app.admin_seed_email to bootstrap admin_users';
    return;
  end if;

  insert into public.admin_users (user_id)
  select u.id
  from auth.users u
  where lower(coalesce(u.email, '')) = v_email
  on conflict (user_id) do nothing;

  update auth.users u
  set raw_app_meta_data =
    coalesce(u.raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
  where lower(coalesce(u.email, '')) = v_email
    and coalesce(u.raw_app_meta_data->>'role', '') is distinct from 'admin';

  raise notice 'admin_seed_applied for %', v_email;
end $$;

notify pgrst, 'reload schema';
