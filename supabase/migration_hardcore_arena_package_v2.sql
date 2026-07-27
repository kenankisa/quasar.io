-- =============================================================================
-- Quasar.io — Hardcore arena package v2 (economy + kill pop split)
-- Run once in Supabase SQL Editor after migration_hardcore_rules_v2.sql.
-- =============================================================================

-- 1) Economy defaults: victory 40 / kill 4 / kill-low 2 / elim 15
update public.app_economy_config
set
  config = config
    || jsonb_build_object(
      'rewardHardcoreKillLowPop',
      coalesce((config->>'rewardHardcoreKillLowPop')::int, 2),
      'hardcoreArenaMinAlive',
      coalesce((config->>'hardcoreArenaMinAlive')::int, 6)
    )
    || case
         when coalesce((config->>'rewardHardcore1')::int, 50) = 50
           then jsonb_build_object('rewardHardcore1', 40)
         else '{}'::jsonb
       end
    || case
         when coalesce((config->>'rewardHardcoreKill')::int, 5) = 5
           then jsonb_build_object('rewardHardcoreKill', 4)
         else '{}'::jsonb
       end
    || case
         when coalesce((config->>'penaltyHardcore')::int, 20) = 20
           then jsonb_build_object('penaltyHardcore', 15)
         else '{}'::jsonb
       end,
  updated_at = timezone('utc', now())
where id = 1;

-- 2) Kill reward: active arena (≥6) vs low pop
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
  v_delta int;
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

  if v_alive >= greatest(2, least(20, public._economy_cfg_int('hardcoreArenaMinAlive', 6))) then
    v_delta := greatest(0, public._economy_cfg_int('rewardHardcoreKill', 4));
  else
    v_delta := greatest(
      0,
      public._economy_cfg_int('rewardHardcoreKillLowPop', 2)
    );
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

-- Keep 2-arg overload callable (PostgREST may still hit old signature briefly).
create or replace function public.apply_hardcore_kill_reward(
  p_room_instance_id uuid,
  p_prey_user_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.apply_hardcore_kill_reward(
    p_room_instance_id,
    p_prey_user_id,
    null
  );
end;
$$;

revoke all on function public.apply_hardcore_kill_reward(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.apply_hardcore_kill_reward(uuid, uuid)
  to authenticated;

-- 3) Placement / elim fallbacks when JSON missing keys
create or replace function public._economy_placement_delta(p_room text, p_placement int)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
begin
  if p_placement is null or p_placement < 1 or p_placement > 3 then
    return 0;
  end if;

  if v_room = 'hardcore' then
    -- Only size-600 victory pays; no podium 2/3
    if p_placement = 1 then
      return greatest(0, public._economy_cfg_int('rewardHardcore1', 40));
    end if;
    return 0;
  end if;

  return case v_room
    when 'simple' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardSimple1', 3))
        when 2 then greatest(0, public._economy_cfg_int('rewardSimple2', 2))
        else greatest(0, public._economy_cfg_int('rewardSimple3', 1))
      end
    when 'elite' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardElite1', 10))
        when 2 then greatest(0, public._economy_cfg_int('rewardElite2', 6))
        else greatest(0, public._economy_cfg_int('rewardElite3', 4))
      end
    when 'unique' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardUnique1', 15))
        when 2 then greatest(0, public._economy_cfg_int('rewardUnique2', 10))
        else greatest(0, public._economy_cfg_int('rewardUnique3', 5))
      end
    else
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardNormal1', 5))
        when 2 then greatest(0, public._economy_cfg_int('rewardNormal2', 3))
        else greatest(0, public._economy_cfg_int('rewardNormal3', 2))
      end
  end;
end;
$$;

create or replace function public._economy_elimination_delta(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
  v_loss int;
begin
  if v_room = 'hardcore' then
    return -greatest(0, public._economy_cfg_int('penaltyHardcore', 15));
  end if;
  v_loss := case v_room
    when 'simple' then greatest(0, public._economy_cfg_int('penaltySimple', 0))
    when 'elite' then greatest(0, public._economy_cfg_int('penaltyElite', 3))
    when 'unique' then greatest(0, public._economy_cfg_int('penaltyUnique', 4))
    else greatest(0, public._economy_cfg_int('penaltyNormal', 2))
  end;
  return -v_loss;
end;
$$;

notify pgrst, 'reload schema';
