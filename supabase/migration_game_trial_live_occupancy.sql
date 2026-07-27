-- =============================================================================
-- Quasar.io — Oyun deneme sim'leri canlı evrenlerde "gerçek oyuncu" gibi sayılsın
--
-- Sorun: is_sim=true olduğu için _room_human_occupancy onları sayıyor →
-- real_player_count=0 → admin/lobi evren listesinde görünmüyorlar.
--
-- Çözüm: load-test sim'leri hariç tut; is_game_trial olanlar insan sayılır.
-- Ayrıca prepare_game_trial_player elmas sıfırlamasını.
-- SQL Editor'da çalıştırın. Safe to re-run.
-- =============================================================================

-- Helpers (idempotent)
create or replace function public._is_game_trial_auth_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (
      select coalesce(u.raw_user_meta_data->>'is_game_trial', '') = 'true'
      from auth.users u
      where u.id = p_user_id
    ),
    false
  );
$$;

revoke all on function public._is_game_trial_auth_user(uuid)
  from public, anon, authenticated;

create or replace function public._is_load_test_sim_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(public._is_sim_auth_user(p_user_id), false)
    and not coalesce(public._is_game_trial_auth_user(p_user_id), false);
$$;

revoke all on function public._is_load_test_sim_user(uuid)
  from public, anon, authenticated;

-- Live humans = real players + game-trial career sims (NOT load-test)
create or replace function public._room_human_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public, auth
as $$
  select count(*)::int
  from public.game_room_members grm
  where grm.room_instance_id = p_room_id
    and grm.left_at is null
    and not public._is_load_test_sim_user(grm.user_id);
$$;

revoke all on function public._room_human_occupancy(uuid)
  from public, anon, authenticated;

-- Load-test only (ghosts + load-test sims; game-trial excluded)
create or replace function public._room_load_test_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public, auth
as $$
  select (
    select count(*)::int
    from public.game_room_members grm
    where grm.room_instance_id = p_room_id
      and grm.left_at is null
      and public._is_load_test_sim_user(grm.user_id)
  ) + (
    select count(*)::int
    from public.load_test_ghosts g
    where g.room_instance_id = p_room_id
  );
$$;

revoke all on function public._room_load_test_occupancy(uuid)
  from public, anon, authenticated;

create or replace function public._room_has_load_test(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public._room_load_test_occupancy(p_room_id) > 0;
$$;

revoke all on function public._room_has_load_test(uuid)
  from public, anon, authenticated;

create or replace function public._room_has_humans(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public._room_human_occupancy(p_room_id) > 0;
$$;

revoke all on function public._room_has_humans(uuid)
  from public, anon, authenticated;

-- Hardcore seats: game-trial counts; load-test + admin do not
create or replace function public._room_hardcore_seat_occupancy(p_room_id uuid)
returns int
language sql
stable
security definer
set search_path = public, auth
as $$
  select count(*)::int
  from public.game_room_members grm
  where grm.room_instance_id = p_room_id
    and grm.left_at is null
    and not public._is_load_test_sim_user(grm.user_id)
    and not coalesce(public._is_admin_user(grm.user_id), false);
$$;

revoke all on function public._room_hardcore_seat_occupancy(uuid)
  from public, anon, authenticated;

-- prepare: never wipe diamonds after tutorial / after earning
create or replace function public.prepare_game_trial_player()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_meta jsonb;
  v_ok boolean := false;
  v_name text;
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

  v_ok :=
    coalesce(v_meta->>'is_game_trial', '') = 'true'
    or (
      coalesce(v_meta->>'is_sim', '') = 'true'
      and (
        coalesce(v_email, '') like 'sim.%@quasar.sim.local'
        or coalesce(v_email, '') like 'sim.%@example.com'
      )
    );

  if not v_ok then
    raise exception 'forbidden';
  end if;

  update auth.users
  set raw_user_meta_data =
    coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('is_sim', true, 'is_game_trial', true)
  where id = v_uid;

  v_name := left(
    coalesce(
      nullif(trim(v_meta->>'full_name'), ''),
      nullif(trim(v_meta->>'name'), ''),
      'Gt' || substr(replace(v_uid::text, '-', ''), 1, 10)
    ),
    12
  );

  begin
    perform public._allow_trusted_profile_write();
  exception when undefined_function then
    null;
  end;

  insert into public.profiles (
    id, username, diamonds, games_won, active_skin,
    trophy_wins_simple, trophy_wins_normal, trophy_wins_elite, trophy_wins_unique,
    hardcore_points, hardcore_cooldown_until, tutorial_completed, updated_at
  ) values (
    v_uid, v_name, 20, 0, 'default',
    0, 0, 0, 0,
    0, null, false, timezone('utc', now())
  )
  on conflict (id) do update
  set
    username = coalesce(nullif(trim(public.profiles.username), ''), excluded.username),
    diamonds = case
      when public.profiles.updated_at > timezone('utc', now()) - interval '10 seconds'
        then public.profiles.diamonds
      when coalesce(public.profiles.tutorial_completed, false)
        or coalesce(public.profiles.diamonds, 0) > 20
        then public.profiles.diamonds
      when coalesce(public.profiles.games_won, 0) = 0
        and coalesce(public.profiles.trophy_wins_normal, 0)
          + coalesce(public.profiles.trophy_wins_elite, 0)
          + coalesce(public.profiles.trophy_wins_unique, 0)
          + coalesce(public.profiles.trophy_wins_simple, 0) = 0
        and coalesce(public.profiles.hardcore_points, 0) = 0
        then 20
      else public.profiles.diamonds
    end,
    updated_at = timezone('utc', now());

  return json_build_object(
    'ok', true,
    'user_id', v_uid,
    'username', v_name,
    'starter', true
  );
end;
$$;

revoke all on function public.prepare_game_trial_player() from public, anon;
grant execute on function public.prepare_game_trial_player() to authenticated;

comment on function public._room_human_occupancy(uuid) is
  'Live occupancy: real players + game-trial sims; excludes load-test sims.';
comment on function public._room_load_test_occupancy(uuid) is
  'Load-test only occupancy (ghosts + load-test sims). Game-trial excluded.';

-- Resync open rooms so existing game-trial members show in real_player_count
do $$
declare
  r uuid;
begin
  for r in
    select distinct grm.room_instance_id
    from public.game_room_members grm
    where grm.left_at is null
  loop
    begin
      perform public._sync_room_occupancy(r);
    exception when others then
      null;
    end;
  end loop;
end $$;
