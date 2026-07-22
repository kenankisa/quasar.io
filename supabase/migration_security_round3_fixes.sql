-- =============================================================================
-- Quasar.io — Security round 3
-- 1) prepare_simulated_player: yalnızca admin-mint kaydı / app_metadata.is_sim
-- 2) Rewarded 2×: client attest varsayılan kapalı; AdMob SSV (service_role) zorunlu
-- 3) (OAuth fail-closed uygulama tarafında — AppConfig.webOAuthRedirectTo)
--
-- SQL Editor'da migration_security_medium_round2.sql / high_anon_sim_mint sonrası.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Sim registry + prepare / _is_sim_auth_user
-- -----------------------------------------------------------------------------

create table if not exists public.sim_players (
  user_id uuid primary key references auth.users (id) on delete cascade,
  minted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.sim_players enable row level security;
revoke all on public.sim_players from public, anon, authenticated;

-- Mevcut sim hesapları backfill + app_metadata kilidi
insert into public.sim_players (user_id, minted_by)
select
  u.id,
  null
from auth.users u
where coalesce(u.raw_app_meta_data->>'is_sim', '') = 'true'
   or coalesce(u.raw_user_meta_data->>'is_sim', '') = 'true'
   or coalesce(u.email, '') like 'sim.%@example.com'
   or coalesce(u.email, '') like 'sim.%@quasar.sim.local'
on conflict (user_id) do nothing;

update auth.users u
set raw_app_meta_data =
  coalesce(u.raw_app_meta_data, '{}'::jsonb) || '{"is_sim":true}'::jsonb
where exists (
  select 1 from public.sim_players s where s.user_id = u.id
)
  and coalesce(u.raw_app_meta_data->>'is_sim', '') is distinct from 'true';

create or replace function public._is_sim_auth_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (
      select
        exists (
          select 1 from public.sim_players s where s.user_id = p_user_id
        )
        or coalesce(u.raw_app_meta_data->>'is_sim', '') = 'true'
      from auth.users u
      where u.id = p_user_id
    ),
    false
  );
$$;

revoke all on function public._is_sim_auth_user(uuid)
  from public, anon, authenticated;

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
  v_meta jsonb;
  v_app jsonb;
  v_name text;
  v_ok boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select u.raw_user_meta_data, u.raw_app_meta_data
  into v_meta, v_app
  from auth.users u
  where u.id = v_uid;

  if not found then
    raise exception 'not authenticated';
  end if;

  -- Kullanıcı raw_user_meta_data / e-posta ile kendini sim yapamaz.
  -- Yalnızca admin_mint_sim_player → sim_players + app_metadata.is_sim.
  v_ok :=
    exists (select 1 from public.sim_players s where s.user_id = v_uid)
    or coalesce(v_app->>'is_sim', '') = 'true';

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
    'sim.%s.%s@quasar.sim.local',
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

  insert into public.sim_players (user_id, minted_by)
  values (v_user_id, v_uid)
  on conflict (user_id) do nothing;

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

-- -----------------------------------------------------------------------------
-- 2) Rewarded 2× — SSV doğrulama; client attest varsayılan kapalı
-- -----------------------------------------------------------------------------

alter table public.match_reward_claims
  add column if not exists ad_double_ssv_txn text;

create unique index if not exists match_reward_claims_ad_double_ssv_txn_uidx
  on public.match_reward_claims (ad_double_ssv_txn)
  where ad_double_ssv_txn is not null;

comment on column public.match_reward_claims.ad_double_attested_at is
  'Set only after AdMob SSV (service_role) or explicit app.ad_double_allow_client_attest.';

comment on column public.match_reward_claims.ad_double_ssv_txn is
  'AdMob SSV transaction_id (idempotency).';

create or replace function public._ad_double_client_attest_allowed()
returns boolean
language sql
stable
as $$
  select lower(coalesce(
    nullif(trim(current_setting('app.ad_double_allow_client_attest', true)), ''),
    'false'
  )) in ('1', 'true', 'on', 'yes');
$$;

revoke all on function public._ad_double_client_attest_allowed()
  from public, anon, authenticated;

-- Client attest: yalnızca GUC açıkken (lokal/dev). Prod: SSV.
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
  if not public._ad_double_client_attest_allowed() then
    raise exception 'ssv_required';
  end if;

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

  -- Dev-only path: reklam süresi için minimum bekleme.
  if v_elapsed_sec < 20 then
    raise exception 'ad_watch_too_short';
  end if;

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

-- AdMob SSV edge function → service_role ile çağırır.
create or replace function public.ssv_attest_rewarded_match_double(
  p_user_id uuid,
  p_session_id uuid,
  p_transaction_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claim public.match_reward_claims%rowtype;
  v_role text := coalesce(
    auth.jwt() ->> 'role',
    auth.role(),
    ''
  );
  v_elapsed_sec double precision;
begin
  if v_role is distinct from 'service_role' then
    raise exception 'forbidden';
  end if;

  if p_user_id is null or p_session_id is null
     or nullif(trim(p_transaction_id), '') is null then
    raise exception 'ad_session_required';
  end if;

  if exists (
    select 1
    from public.match_reward_claims c
    where c.ad_double_ssv_txn = trim(p_transaction_id)
  ) then
    return true;
  end if;

  select *
  into v_claim
  from public.match_reward_claims
  where user_id = p_user_id
    and ad_double_session_id = p_session_id
    and claim_kind = 'reward'
    and diamond_delta > 0
    and ad_double_claimed_at is null
  for update;

  if not found then
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
    update public.match_reward_claims
    set ad_double_ssv_txn = coalesce(ad_double_ssv_txn, trim(p_transaction_id))
    where id = v_claim.id
      and ad_double_ssv_txn is null;
    return true;
  end if;

  update public.match_reward_claims
  set
    ad_double_attested_at = timezone('utc', now()),
    ad_double_ssv_txn = trim(p_transaction_id)
  where id = v_claim.id
    and ad_double_claimed_at is null
    and ad_double_session_id = p_session_id;

  return true;
end;
$$;

revoke all on function public.ssv_attest_rewarded_match_double(uuid, uuid, text)
  from public, anon, authenticated;
-- service_role bypasses revoke via PostgREST; no grant to clients.

create or replace function public.is_rewarded_match_double_attested(
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
  v_match_gen int;
  v_attested boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_room_instance_id is null or p_session_id is null then
    return false;
  end if;

  select *
  into v_room_row
  from public.game_room_instances
  where id = p_room_instance_id;

  if not found then
    return false;
  end if;

  if lower(v_room_row.room_type) <> v_room then
    return false;
  end if;

  v_match_gen := coalesce(v_room_row.match_generation, 1);

  select (c.ad_double_attested_at is not null)
  into v_attested
  from public.match_reward_claims c
  where c.user_id = v_uid
    and c.room_instance_id = p_room_instance_id
    and c.match_generation = v_match_gen
    and c.claim_kind = 'reward'
    and c.diamond_delta > 0
    and c.ad_double_session_id = p_session_id;

  return coalesce(v_attested, false);
end;
$$;

revoke all on function public.is_rewarded_match_double_attested(text, uuid, uuid)
  from public, anon;
grant execute on function public.is_rewarded_match_double_attested(text, uuid, uuid)
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
  v_elapsed_prepare double precision;
  v_elapsed_attest double precision;
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

  -- Prod: SSV txn zorunlu (dev client-attest GUC açıkken muaf).
  if not public._ad_double_client_attest_allowed()
     and nullif(trim(coalesce(v_claim.ad_double_ssv_txn, '')), '') is null then
    raise exception 'ssv_required';
  end if;

  v_elapsed_prepare := extract(
    epoch from (timezone('utc', now()) - v_claim.ad_double_prepared_at)
  );
  v_elapsed_attest := extract(
    epoch from (timezone('utc', now()) - v_claim.ad_double_attested_at)
  );

  if v_elapsed_prepare < 15 then
    raise exception 'ad_watch_too_short';
  end if;

  -- Attest sonrası kısa bekleme (anlık prepare→attest→claim otomasyonunu zorlaştırır).
  if v_elapsed_attest < 2 then
    raise exception 'ad_watch_too_short';
  end if;

  if v_elapsed_prepare > 300 then
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

notify pgrst, 'reload schema';

-- Dev/test (SQL Editor, session):
--   select set_config('app.ad_double_allow_client_attest', 'true', false);
-- Prod: AdMob rewarded unit SSV URL →
--   https://<project-ref>.supabase.co/functions/v1/admob-ssv
