-- Universe trophies: per-room 1st-place cups (lobby display).
-- Caps: simple 1 · normal/elite/unique 3  →  max 10 (future hardcore gate).
-- Run after migration_app_economy_config.sql.

-- -----------------------------------------------------------------------------
-- 1) Columns
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists trophy_wins_simple int not null default 0,
  add column if not exists trophy_wins_normal int not null default 0,
  add column if not exists trophy_wins_elite int not null default 0,
  add column if not exists trophy_wins_unique int not null default 0;

alter table public.profiles
  drop constraint if exists profiles_trophy_wins_simple_check,
  drop constraint if exists profiles_trophy_wins_normal_check,
  drop constraint if exists profiles_trophy_wins_elite_check,
  drop constraint if exists profiles_trophy_wins_unique_check;

alter table public.profiles
  add constraint profiles_trophy_wins_simple_check
    check (trophy_wins_simple >= 0 and trophy_wins_simple <= 1),
  add constraint profiles_trophy_wins_normal_check
    check (trophy_wins_normal >= 0 and trophy_wins_normal <= 3),
  add constraint profiles_trophy_wins_elite_check
    check (trophy_wins_elite >= 0 and trophy_wins_elite <= 3),
  add constraint profiles_trophy_wins_unique_check
    check (trophy_wins_unique >= 0 and trophy_wins_unique <= 3);

-- Training already completed → light the single training cup.
update public.profiles
set trophy_wins_simple = 1
where coalesce(tutorial_completed, false) = true
  and coalesce(trophy_wins_simple, 0) < 1;

-- -----------------------------------------------------------------------------
-- 2) Guard — clients cannot write trophy fields
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
     or NEW.rank_points is distinct from OLD.rank_points
     or NEW.active_skin is distinct from OLD.active_skin
     or NEW.peak_diamonds is distinct from OLD.peak_diamonds
     or NEW.skill_tree is distinct from OLD.skill_tree
     or NEW.trophy_wins_simple is distinct from OLD.trophy_wins_simple
     or NEW.trophy_wins_normal is distinct from OLD.trophy_wins_normal
     or NEW.trophy_wins_elite is distinct from OLD.trophy_wins_elite
     or NEW.trophy_wins_unique is distinct from OLD.trophy_wins_unique then
    raise exception 'forbidden_profile_field';
  end if;

  return NEW;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3) apply_match_result — award cup on verified 1st place
-- -----------------------------------------------------------------------------

create or replace function public.apply_match_result(
  p_room_type text default 'normal',
  p_placement int default null,
  p_eliminated boolean default false,
  p_room_instance_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_delta int := 0;
  v_won int := 0;
  v_rank_delta int := 0;
  v_new_diamonds int;
  v_kind text;
  v_member record;
  v_room_row public.game_room_instances%rowtype;
  v_session public.analytics_play_sessions%rowtype;
  v_reward_count int;
  v_simple_reward_count int;
  v_last_reward_at timestamptz;
  v_day_diamonds int;
  v_min_seconds int := 60;
  v_peak int;
  v_match_gen int;
  v_reward_limit int;
  v_training_limit int;
  v_day_cap int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if coalesce(p_eliminated, false) then
    v_kind := 'penalty';
    v_delta := public._economy_elimination_delta(v_room);
  else
    v_kind := 'reward';
    if p_placement is null or p_placement < 1 or p_placement > 3 then
      select diamonds into v_new_diamonds
      from public.profiles
      where id = v_uid;
      return coalesce(v_new_diamonds, 0);
    end if;

    v_delta := public._economy_placement_delta(v_room, p_placement);

    if p_placement = 1 and v_room <> 'simple' then
      v_won := 1;
    elsif p_placement = 1 and v_room = 'simple' then
      v_won := 0;
    end if;

    if v_won = 1 then
      v_rank_delta := public._rank_win_points_for_room(v_room);
    end if;
  end if;

  if v_delta = 0 and v_won = 0 and v_rank_delta = 0
     and not (v_kind = 'reward' and coalesce(p_placement, 0) = 1) then
    select diamonds into v_new_diamonds
    from public.profiles
    where id = v_uid;
    return coalesce(v_new_diamonds, 0);
  end if;

  if not public._is_admin_user(v_uid) then
    if v_room = 'simple' then
      v_min_seconds := 90;
    end if;

    select *
    into v_session
    from public.analytics_play_sessions s
    where s.user_id = v_uid
      and s.room_type = v_room
      and (
        s.ended_at is null
        or s.ended_at >= timezone('utc', now()) - interval '15 minutes'
      )
      and not exists (
        select 1
        from public.match_reward_claims c
        where c.play_session_id = s.id
      )
    order by s.started_at desc
    limit 1
    for update;

    if not found then
      select *
      into v_session
      from public.analytics_play_sessions
      where user_id = v_uid
        and room_type = v_room
        and (
          ended_at is null
          or ended_at >= timezone('utc', now()) - interval '15 minutes'
        )
      order by started_at desc
      limit 1
      for update;
    end if;

    if not found then
      raise exception 'no_play_session';
    end if;

    if v_session.started_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
      raise exception 'match_too_short';
    end if;

    if v_room = 'simple' then
      if p_room_instance_id is not null then
        raise exception 'training_no_room_instance';
      end if;
      v_match_gen := null;
    else
      if p_room_instance_id is null then
        raise exception 'room_instance_required';
      end if;

      select * into v_room_row
      from public.game_room_instances
      where id = p_room_instance_id
      for update;

      if not found then
        raise exception 'room_not_found';
      end if;

      if lower(v_room_row.room_type) <> v_room then
        raise exception 'room_type_mismatch';
      end if;

      v_match_gen := coalesce(v_room_row.match_generation, 1);

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

      if v_member.joined_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
        raise exception 'match_too_short';
      end if;

      v_peak := greatest(
        coalesce(v_room_row.peak_leader_radius, 25),
        coalesce(v_room_row.leader_radius, 25)
      );

      if v_kind = 'reward' and p_placement = 1 then
        if v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;

      if v_kind = 'reward' and p_placement in (2, 3) then
        if v_peak < 180 then
          raise exception 'placement_not_verified';
        end if;
      end if;
    end if;

    if v_kind = 'reward' then
      v_reward_limit := greatest(1, public._economy_cfg_int('rewardClaimsPerDay', 25));
      v_training_limit := greatest(1, public._economy_cfg_int('trainingClaimsPerDay', 8));
      v_day_cap := greatest(1, public._economy_cfg_int('dailyMatchDiamondCap', 120));

      select count(*)::int, max(created_at)
      into v_reward_count, v_last_reward_at
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_reward_count, 0) >= v_reward_limit then
        raise exception 'reward_daily_limit';
      end if;

      if v_room = 'simple' then
        select count(*)::int
        into v_simple_reward_count
        from public.match_reward_claims
        where user_id = v_uid
          and claim_kind = 'reward'
          and room_type = 'simple'
          and created_at >= timezone('utc', now()) - interval '24 hours';

        if coalesce(v_simple_reward_count, 0) >= v_training_limit then
          raise exception 'training_daily_limit';
        end if;
      end if;

      if v_last_reward_at is not null
         and v_last_reward_at > timezone('utc', now()) - interval '60 seconds' then
        raise exception 'reward_cooldown';
      end if;

      select coalesce(sum(greatest(diamond_delta, 0)), 0)::int
      into v_day_diamonds
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap then
        raise exception 'diamond_daily_cap';
      end if;
    end if;

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
        v_room,
        case when v_room = 'simple' then null else p_room_instance_id end,
        v_session.id,
        v_kind,
        case when v_kind = 'penalty' then null else p_placement end,
        v_delta,
        v_match_gen
      );
    exception
      when unique_violation then
        raise exception 'already_claimed';
    end;
  end if;

  perform public._allow_trusted_profile_write();
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config(
    'quasar.analytics_placement',
    case
      when v_kind = 'penalty' then ''
      else coalesce(p_placement::text, '')
    end,
    true
  );
  perform set_config(
    'quasar.analytics_eliminated',
    case when v_kind = 'penalty' then 'true' else 'false' end,
    true
  );

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    games_won = games_won + v_won,
    rank_points = greatest(0, coalesce(rank_points, 0) + v_rank_delta),
    tutorial_completed = coalesce(tutorial_completed, false)
      or (v_room = 'simple' and v_kind = 'reward' and coalesce(p_placement, 0) = 1),
    trophy_wins_simple = case
      when v_room = 'simple' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(1, coalesce(trophy_wins_simple, 0) + 1)
      else trophy_wins_simple
    end,
    trophy_wins_normal = case
      when v_room = 'normal' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_normal, 0) + 1)
      else trophy_wins_normal
    end,
    trophy_wins_elite = case
      when v_room = 'elite' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_elite, 0) + 1)
      else trophy_wins_elite
    end,
    trophy_wins_unique = case
      when v_room = 'unique' and v_kind = 'reward' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_unique, 0) + 1)
      else trophy_wins_unique
    end,
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

revoke all on function public.apply_match_result(text, int, boolean, uuid) from public;
grant execute on function public.apply_match_result(text, int, boolean, uuid) to authenticated;

notify pgrst, 'reload schema';
