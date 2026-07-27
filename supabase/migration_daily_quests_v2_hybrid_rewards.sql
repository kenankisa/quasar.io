-- Daily quests v2: hybrid rewards
-- Per quest (auto on complete): easy 2 / medium 4 / hard 6 diamonds
-- 2/3 partial bundle: 4 diamonds
-- 3/3 full bundle roll: 8 / 15 / 22 (50% / 35% / 15%)
-- Run after migration_daily_quests.sql

alter table public.daily_quest_day_stats
  add column if not exists bundle_reward int,
  add column if not exists partial_bundle_claimed_at timestamptz,
  add column if not exists full_bundle_claimed_at timestamptz;

update public.daily_quest_day_stats
set bundle_reward = 8
where bundle_reward is null;

alter table public.daily_quest_day_stats
  alter column bundle_reward set default 8;

create or replace function public._daily_quest_completion_reward(p_difficulty text)
returns int
language sql
immutable
as $$
  select case lower(p_difficulty)
    when 'easy' then 2
    when 'medium' then 4
    when 'hard' then 6
    else 2
  end;
$$;

create or replace function public._daily_quest_roll_bundle()
returns int
language plpgsql
as $$
declare
  v_roll double precision := random();
begin
  return case
    when v_roll < 0.50 then 8
    when v_roll < 0.85 then 15
    else 22
  end;
end;
$$;

create or replace function public._daily_quest_grant_diamonds(
  p_user_id uuid,
  p_amount int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new int;
begin
  if p_amount is null or p_amount <= 0 then
    select diamonds into v_new from public.profiles where id = p_user_id;
    return coalesce(v_new, 0);
  end if;

  perform public._allow_trusted_profile_write();

  update public.profiles
  set
    diamonds = greatest(0, diamonds + p_amount),
    updated_at = timezone('utc', now())
  where id = p_user_id
  returning diamonds into v_new;

  if v_new is null then
    raise exception 'profile_missing';
  end if;

  return v_new;
end;
$$;

create or replace function public._daily_quest_ensure_assignments(
  p_user_id uuid,
  p_day date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_diff text;
  v_quest_id text;
begin
  insert into public.daily_quest_day_stats (
    user_id, quest_day, bundle_reward
  )
  values (
    p_user_id, p_day, public._daily_quest_roll_bundle()
  )
  on conflict (user_id, quest_day) do nothing;

  if exists (
    select 1
    from public.daily_quest_assignments a
    where a.user_id = p_user_id
      and a.quest_day = p_day
  ) then
    return;
  end if;

  foreach v_diff in array array['easy', 'medium', 'hard'] loop
    v_quest_id := public._daily_quest_pick_id(v_diff, p_user_id, p_day);
    if v_quest_id is null then
      continue;
    end if;

    insert into public.daily_quest_assignments (
      user_id,
      quest_day,
      quest_id,
      difficulty,
      reward_diamonds,
      progress,
      target
    )
    values (
      p_user_id,
      p_day,
      v_quest_id,
      v_diff,
      public._daily_quest_completion_reward(v_diff),
      0,
      public._daily_quest_target(v_quest_id)
    );
  end loop;
end;
$$;

create or replace function public._daily_quest_process_bundles(
  p_user_id uuid,
  p_day date,
  p_grants jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_completed int;
  v_stats public.daily_quest_day_stats%rowtype;
  v_partial constant int := 4;
  v_grants jsonb := coalesce(p_grants, '[]'::jsonb);
begin
  select *
  into v_stats
  from public.daily_quest_day_stats s
  where s.user_id = p_user_id
    and s.quest_day = p_day
  for update;

  if not found then
    return v_grants;
  end if;

  select count(*)::int
  into v_completed
  from public.daily_quest_assignments a
  where a.user_id = p_user_id
    and a.quest_day = p_day
    and a.completed_at is not null;

  if v_completed >= 2
     and v_stats.partial_bundle_claimed_at is null
     and v_stats.full_bundle_claimed_at is null then
    update public.daily_quest_day_stats
    set
      partial_bundle_claimed_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    where user_id = p_user_id
      and quest_day = p_day;

    perform public._daily_quest_grant_diamonds(p_user_id, v_partial);
    v_grants := v_grants || jsonb_build_array(
      jsonb_build_object('kind', 'partial', 'diamonds', v_partial)
    );
  end if;

  if v_completed >= 3 and v_stats.full_bundle_claimed_at is null then
    update public.daily_quest_day_stats
    set
      full_bundle_claimed_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    where user_id = p_user_id
      and quest_day = p_day;

    perform public._daily_quest_grant_diamonds(
      p_user_id,
      coalesce(v_stats.bundle_reward, 8)
    );
    v_grants := v_grants || jsonb_build_array(
      jsonb_build_object(
        'kind', 'full',
        'diamonds', coalesce(v_stats.bundle_reward, 8)
      )
    );
  end if;

  return v_grants;
end;
$$;

create or replace function public._daily_quest_build_status(
  p_user_id uuid,
  p_day date,
  p_grants jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reset timestamptz := ((p_day + 1)::timestamp at time zone 'utc');
  v_quests jsonb;
  v_completed int;
  v_bundle int;
  v_partial boolean;
  v_full boolean;
begin
  select count(*)::int
  into v_completed
  from public.daily_quest_assignments a
  where a.user_id = p_user_id
    and a.quest_day = p_day
    and a.completed_at is not null;

  select
    coalesce(s.bundle_reward, 8),
    s.partial_bundle_claimed_at is not null,
    s.full_bundle_claimed_at is not null
  into v_bundle, v_partial, v_full
  from public.daily_quest_day_stats s
  where s.user_id = p_user_id
    and s.quest_day = p_day;

  if v_bundle is null then
    v_bundle := 8;
    v_partial := false;
    v_full := false;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'quest_id', a.quest_id,
        'difficulty', a.difficulty,
        'reward_diamonds', a.reward_diamonds,
        'progress', a.progress,
        'target', a.target,
        'completed', a.completed_at is not null,
        'claimed', a.claimed_at is not null
      )
      order by case a.difficulty
        when 'easy' then 1
        when 'medium' then 2
        else 3
      end
    ),
    '[]'::jsonb
  )
  into v_quests
  from public.daily_quest_assignments a
  where a.user_id = p_user_id
    and a.quest_day = p_day;

  return jsonb_build_object(
    'quest_day', p_day,
    'next_reset_at', v_reset,
    'quests', v_quests,
    'completed_count', coalesce(v_completed, 0),
    'bundle_reward', v_bundle,
    'partial_bundle_claimed', coalesce(v_partial, false),
    'full_bundle_claimed', coalesce(v_full, false),
    'grants', coalesce(p_grants, '[]'::jsonb)
  );
end;
$$;

create or replace function public.get_daily_quests_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._daily_quest_ensure_assignments(v_uid, v_day);

  return public._daily_quest_build_status(v_uid, v_day);
end;
$$;

create or replace function public.report_daily_quest_match(
  p_room_type text,
  p_placement int default null,
  p_eliminated boolean default false,
  p_peak_radius numeric default 0,
  p_survival_seconds numeric default 0,
  p_particles_absorbed int default 0,
  p_player_kills int default 0,
  p_bot_kills int default 0,
  p_shield_uses int default 0,
  p_match_completed boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
  v_matches int;
  v_wins int;
  v_hc_unlocked boolean;
  r public.daily_quest_assignments%rowtype;
  v_eval record;
  v_grants jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not coalesce(p_match_completed, false) then
    return public.get_daily_quests_status();
  end if;

  perform public._daily_quest_ensure_assignments(v_uid, v_day);

  insert into public.daily_quest_day_stats (user_id, quest_day, matches_completed, wins, bundle_reward)
  values (
    v_uid,
    v_day,
    1,
    case
      when not coalesce(p_eliminated, false)
           and coalesce(p_placement, 0) = 1 then 1
      else 0
    end,
    public._daily_quest_roll_bundle()
  )
  on conflict (user_id, quest_day) do update
  set
    matches_completed = public.daily_quest_day_stats.matches_completed + 1,
    wins = public.daily_quest_day_stats.wins + excluded.wins,
    updated_at = timezone('utc', now());

  select s.matches_completed, s.wins
  into v_matches, v_wins
  from public.daily_quest_day_stats s
  where s.user_id = v_uid
    and s.quest_day = v_day;

  v_hc_unlocked := public._daily_quest_hardcore_unlocked(v_uid);

  for r in
    select *
    from public.daily_quest_assignments a
    where a.user_id = v_uid
      and a.quest_day = v_day
      and a.completed_at is null
  loop
    select *
    into v_eval
    from public._daily_quest_evaluate_row(
      r,
      p_room_type,
      p_placement,
      p_eliminated,
      p_peak_radius,
      p_survival_seconds,
      p_particles_absorbed,
      p_player_kills,
      p_bot_kills,
      p_shield_uses,
      p_match_completed,
      v_matches,
      v_wins,
      v_hc_unlocked
    );

    if v_eval.newly_completed then
      update public.daily_quest_assignments a
      set
        progress = v_eval.new_progress,
        completed_at = timezone('utc', now()),
        claimed_at = timezone('utc', now())
      where a.id = r.id;

      perform public._daily_quest_grant_diamonds(v_uid, r.reward_diamonds);
      v_grants := v_grants || jsonb_build_array(
        jsonb_build_object(
          'kind', 'quest',
          'quest_id', r.quest_id,
          'diamonds', r.reward_diamonds
        )
      );
    else
      update public.daily_quest_assignments a
      set progress = v_eval.new_progress
      where a.id = r.id;
    end if;
  end loop;

  v_grants := public._daily_quest_process_bundles(v_uid, v_day, v_grants);

  return public._daily_quest_build_status(v_uid, v_day, v_grants);
end;
$$;

-- Legacy manual claim disabled (rewards are automatic).
create or replace function public.claim_daily_quest_reward(p_quest_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return jsonb_build_object(
    'ok', false,
    'reason', 'auto_reward',
    'status', public.get_daily_quests_status()
  );
end;
$$;

-- Fix existing rows: per-quest rewards = 2/4/6 by difficulty.
update public.daily_quest_assignments a
set reward_diamonds = public._daily_quest_completion_reward(a.difficulty)
where a.claimed_at is null
   or a.reward_diamonds > 3;

notify pgrst, 'reload schema';
