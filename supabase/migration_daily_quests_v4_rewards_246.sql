-- Daily quests v4: reward bump to 2 / 4 / 6 by difficulty
-- Run after migration_daily_quests_v3_simple_rewards.sql

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

update public.daily_quest_assignments a
set reward_diamonds = public._daily_quest_completion_reward(a.difficulty)
where a.completed_at is null
  and a.reward_diamonds is distinct from public._daily_quest_completion_reward(a.difficulty);

notify pgrst, 'reload schema';
