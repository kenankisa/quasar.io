-- Hardcore passive mode (< min-alive): no kill/elim diamonds, 5 min re-entry cooldown.
-- Active mode (6+ alive): unchanged kill rewards + elim penalty + 1h cooldown.

-- Kill reward: only when arena is active (6+ alive).
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

-- Passive elim: server verifies < min-alive, sets 5 min cooldown, no diamond change.
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

comment on function public.apply_hardcore_passive_elim(uuid) is
  'Hardcore passive elim (< min-alive): 5 min cooldown, no diamond penalty.';

notify pgrst, 'reload schema';
