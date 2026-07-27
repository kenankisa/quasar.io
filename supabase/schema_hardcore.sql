-- =============================================================================
-- Quasar.io — Hardcore universe package (consolidated reference)
--
-- PURPOSE
--   Single-file bootstrap for NEW databases that already ran base schema.sql
--   and economy/security migrations. Documents the *final* Hardcore surface area.
--
-- DO NOT run on production that already applied incremental migrations unless
-- you diff each object first. See supabase/HARDCORE_MIGRATIONS.md.
--
-- SUPERSEDES (incremental chain — run in order on brownfield):
--   migration_hardcore_universe.sql
--   migration_hardcore_rules_v2.sql
--   migration_hardcore_arena_package_v2.sql
--   migration_hardcore_singleton_always_open.sql
--   migration_hardcore_admin_seat_exempt.sql
--   migration_hardcore_seat_release.sql
--   migration_hardcore_match_afk_idle.sql
--   migration_hardcore_passive_mode_economy.sql
--   migration_admin_hardcore_live_ops.sql
--   (+ arena test / game trial / rank / announce patches — see HARDCORE_MIGRATIONS.md)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Profile columns
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists hardcore_points int not null default 0;

alter table public.profiles
  add column if not exists hardcore_cooldown_until timestamptz;

comment on column public.profiles.hardcore_points is
  'Hardcore victories (1 point = 1 hardcore win)';
comment on column public.profiles.hardcore_cooldown_until is
  'Cannot join hardcore until this UTC time (active win/elim ~1h; passive elim ~5m)';

-- -----------------------------------------------------------------------------
-- 2) Queue + kill-claim tables
-- -----------------------------------------------------------------------------
create table if not exists public.hardcore_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  enqueued_at timestamptz not null default timezone('utc', now()),
  admitted_room_id uuid references public.game_room_instances (id) on delete set null,
  admitted_at timestamptz,
  match_generation int
);

create index if not exists hardcore_queue_waiting_idx
  on public.hardcore_queue (enqueued_at asc)
  where admitted_room_id is null;

alter table public.hardcore_queue enable row level security;

drop policy if exists hardcore_queue_select_own on public.hardcore_queue;
create policy hardcore_queue_select_own
  on public.hardcore_queue for select to authenticated
  using (user_id = auth.uid());

create table if not exists public.hardcore_kill_claims (
  id uuid primary key default gen_random_uuid(),
  predator_id uuid not null references auth.users (id) on delete cascade,
  prey_id uuid not null,
  room_instance_id uuid not null references public.game_room_instances (id) on delete cascade,
  match_generation int not null default 1,
  diamond_delta int not null default 4,
  created_at timestamptz not null default timezone('utc', now()),
  unique (predator_id, prey_id, room_instance_id, match_generation)
);

create index if not exists hardcore_kill_claims_pred_idx
  on public.hardcore_kill_claims (predator_id, created_at desc);

alter table public.hardcore_kill_claims enable row level security;

-- -----------------------------------------------------------------------------
-- 3) Room tuning row
-- -----------------------------------------------------------------------------
insert into public.room_game_tuning (room_type, config)
values (
  'hardcore',
  jsonb_build_object(
    'v', 1,
    'maxPlayers', 20,
    'victoryRadius', 600,
    'hardcoreArena', jsonb_build_object(
      'spawnProtectionSeconds', 12,
      'victoryMinAlive', 6,
      'victoryStableSeconds', 20,
      'victoryMinPvpMassFraction', 0.35,
      'lateFoodSoftcapRadius', 450,
      'lateFoodSoftcapMultiplier', 0.5,
      'lowPopRadiusCap', 450,
      'foodPopMult1', 0.15,
      'foodPopMult2', 0.35,
      'foodPopMult34', 0.55,
      'foodPopMult5', 0.75,
      'foodPopMult6Plus', 1.0
    )
  )
)
on conflict (room_type) do nothing;

-- -----------------------------------------------------------------------------
-- 4) Economy RPCs (latest — passive mode)
--     Full join/queue/singleton/admin RPCs: apply incremental chain documented
--     in HARDCORE_MIGRATIONS.md (rules_v2 + singleton + live_ops).
--     Below: kill reward + passive elim (copy of migration_hardcore_passive_mode_economy.sql).
-- -----------------------------------------------------------------------------

create or replace function public.apply_hardcore_kill_reward(
  p_room_instance_id uuid,
  p_prey_user_id uuid,
  p_alive_count int default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_gen int;
  v_alive int;
  v_min_alive int;
  v_delta int := 0;
  v_new int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_room_instance_id is null or p_prey_user_id is null then
    raise exception 'invalid_args';
  end if;
  if p_prey_user_id = v_uid then
    raise exception 'cannot_kill_self';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found then
    raise exception 'room_not_found';
  end if;
  if lower(v_room.room_type) <> 'hardcore' then
    raise exception 'not_hardcore_room';
  end if;

  if not exists (
    select 1 from public.game_room_members
    where room_instance_id = p_room_instance_id
      and user_id = v_uid
      and (
        left_at is null
        or left_at >= timezone('utc', now()) - interval '2 hours'
      )
  ) then
    raise exception 'not_room_member';
  end if;

  v_min_alive := greatest(2, least(20, public._economy_cfg_int('hardcoreArenaMinAlive', 6)));

  v_alive := coalesce(
    nullif(p_alive_count, 0),
    (
      select count(*)::int
      from public.game_room_members
      where room_instance_id = p_room_instance_id
        and left_at is null
    ),
    1
  );
  v_alive := greatest(1, least(20, v_alive));

  if v_alive >= v_min_alive then
    v_delta := greatest(0, public._economy_cfg_int('rewardHardcoreKill', 4));
  end if;

  if v_delta <= 0 then
    select diamonds into v_new from public.profiles where id = v_uid;
    return coalesce(v_new, 0);
  end if;

  v_gen := coalesce(v_room.match_generation, 1);

  begin
    insert into public.hardcore_kill_claims (
      predator_id, prey_id, room_instance_id, match_generation, diamond_delta
    ) values (v_uid, p_prey_user_id, p_room_instance_id, v_gen, v_delta);
  exception when unique_violation then
    select diamonds into v_new from public.profiles where id = v_uid;
    return coalesce(v_new, 0);
  end;

  perform public._allow_trusted_profile_write();
  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new;

  return coalesce(v_new, 0);
end;
$$;

revoke all on function public.apply_hardcore_kill_reward(uuid, uuid, int)
  from public, anon, authenticated;
grant execute on function public.apply_hardcore_kill_reward(uuid, uuid, int)
  to authenticated;

create or replace function public.apply_hardcore_passive_elim(
  p_room_instance_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_member public.game_room_members%rowtype;
  v_session public.analytics_play_sessions%rowtype;
  v_alive int;
  v_min_alive int;
  v_match_gen int;
  v_new int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_room_instance_id is null then
    raise exception 'room_instance_required';
  end if;
  if public._is_admin_user(v_uid) then
    select diamonds into v_new from public.profiles where id = v_uid;
    return coalesce(v_new, 0);
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found then
    raise exception 'room_not_found';
  end if;
  if lower(v_room.room_type) <> 'hardcore' then
    raise exception 'not_hardcore_room';
  end if;

  v_min_alive := greatest(2, least(20, public._economy_cfg_int('hardcoreArenaMinAlive', 6)));

  v_alive := (
    select count(*)::int
    from public.game_room_members
    where room_instance_id = p_room_instance_id
      and left_at is null
  );
  v_alive := greatest(0, least(20, coalesce(v_alive, 0)));

  if v_alive >= v_min_alive then
    raise exception 'hardcore_arena_active';
  end if;

  select *
  into v_session
  from public.analytics_play_sessions
  where user_id = v_uid
    and room_type = 'hardcore'
    and (
      ended_at is null
      or ended_at >= timezone('utc', now()) - interval '15 minutes'
    )
  order by started_at desc
  limit 1
  for update;

  if not found then
    raise exception 'no_play_session';
  end if;

  select *
  into v_member
  from public.game_room_members
  where room_instance_id = p_room_instance_id
    and user_id = v_uid
    and (
      left_at is null
      or left_at >= timezone('utc', now()) - interval '2 hours'
    )
  order by joined_at desc
  limit 1
  for update;

  if not found then
    raise exception 'not_room_member';
  end if;

  v_match_gen := coalesce(v_room.match_generation, 1);

  begin
    insert into public.match_reward_claims (
      user_id,
      room_type,
      room_instance_id,
      play_session_id,
      claim_kind,
      placement,
      diamond_delta,
      match_generation
    )
    values (
      v_uid,
      'hardcore',
      p_room_instance_id,
      v_session.id,
      'penalty',
      null,
      0,
      v_match_gen
    );
  exception
    when unique_violation then
      raise exception 'already_claimed';
  end;

  perform public._allow_trusted_profile_write();
  update public.profiles
  set
    hardcore_cooldown_until = timezone('utc', now()) + interval '5 minutes',
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new;

  return coalesce(v_new, 0);
end;
$$;

revoke all on function public.apply_hardcore_passive_elim(uuid)
  from public, anon, authenticated;
grant execute on function public.apply_hardcore_passive_elim(uuid)
  to authenticated;

notify pgrst, 'reload schema';
