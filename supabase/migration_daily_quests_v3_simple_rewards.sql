-- Daily quests v3: per-quest rewards only (no bundle / partial / full roll)
-- Easy +2, medium +4, hard +6 — auto-granted on completion
-- Run after migration_daily_quests.sql and migration_daily_quests_v2_hybrid_rewards.sql

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
  insert into public.daily_quest_day_stats (user_id, quest_day)
  values (p_user_id, p_day)
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
begin
  select count(*)::int
  into v_completed
  from public.daily_quest_assignments a
  where a.user_id = p_user_id
    and a.quest_day = p_day
    and a.completed_at is not null;

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
    'grants', coalesce(p_grants, '[]'::jsonb)
  );
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

  insert into public.daily_quest_day_stats (user_id, quest_day, matches_completed, wins)
  values (
    v_uid,
    v_day,
    1,
    case
      when not coalesce(p_eliminated, false)
           and coalesce(p_placement, 0) = 1 then 1
      else 0
    end
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

  return public._daily_quest_build_status(v_uid, v_day, v_grants);
end;
$$;

drop function if exists public._daily_quest_process_bundles(uuid, date, jsonb);
drop function if exists public._daily_quest_roll_bundle();

update public.daily_quest_assignments a
set reward_diamonds = public._daily_quest_completion_reward(a.difficulty)
where a.reward_diamonds is distinct from public._daily_quest_completion_reward(a.difficulty);

notify pgrst, 'reload schema';
