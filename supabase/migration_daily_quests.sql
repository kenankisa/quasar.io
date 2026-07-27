-- Daily quests: 30-quest pool (10 easy / 10 medium / 10 hard).
-- Each UTC day: 1 random quest per difficulty tier + rolled diamond reward.
-- Progress synced from client after each match; rewards claimed manually.

create table if not exists public.daily_quest_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  quest_day date not null default (timezone('utc', now()))::date,
  quest_id text not null,
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
  reward_diamonds int not null check (reward_diamonds > 0),
  progress int not null default 0,
  target int not null default 1,
  completed_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  constraint daily_quest_assignments_quest_id_chk check (
    quest_id ~ '^[KOZ][0-9]{1,2}$'
  )
);

create unique index if not exists daily_quest_assignments_user_day_quest_uidx
  on public.daily_quest_assignments (user_id, quest_day, quest_id);

create index if not exists daily_quest_assignments_user_day_idx
  on public.daily_quest_assignments (user_id, quest_day);

create table if not exists public.daily_quest_day_stats (
  user_id uuid not null references public.profiles (id) on delete cascade,
  quest_day date not null default (timezone('utc', now()))::date,
  matches_completed int not null default 0,
  wins int not null default 0,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, quest_day)
);

alter table public.daily_quest_assignments enable row level security;
alter table public.daily_quest_day_stats enable row level security;

revoke all on table public.daily_quest_assignments from public, anon, authenticated;
revoke all on table public.daily_quest_day_stats from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public._daily_quest_pool(p_difficulty text)
returns text[]
language sql
immutable
as $$
  select case lower(p_difficulty)
    when 'easy' then array[
      'K1','K2','K3','K4','K5','K6','K7','K8','K9','K10'
    ]
    when 'medium' then array[
      'O1','O2','O3','O4','O5','O6','O7','O8','O9','O10'
    ]
    when 'hard' then array[
      'Z1','Z2','Z3','Z4','Z5','Z6','Z7','Z8','Z9','Z10'
    ]
    else array[]::text[]
  end;
$$;

create or replace function public._daily_quest_target(p_quest_id text)
returns int
language sql
immutable
as $$
  select case p_quest_id
    when 'K2' then 50
    when 'K3' then 80
    when 'K4' then 20
    when 'K5' then 40
    when 'K6' then 60
    when 'K7' then 90
    when 'K8' then 1
    when 'O1' then 10
    when 'O2' then 5
    when 'O3' then 1
    when 'O4' then 120
    when 'O5' then 150
    when 'O6' then 1
    when 'O7' then 2
    when 'O8' then 80
    when 'O10' then 3
    when 'Z1' then 3
    when 'Z2' then 1
    when 'Z3' then 2
    when 'Z4' then 3
    when 'Z5' then 200
    when 'Z6' then 280
    when 'Z7' then 3
    when 'Z8' then 2
    when 'Z9' then 1
    when 'Z10' then 1
    else 1
  end;
$$;

create or replace function public._daily_quest_roll_reward(p_difficulty text)
returns int
language plpgsql
as $$
declare
  v_roll double precision := random();
begin
  return case lower(p_difficulty)
    when 'easy' then
      case
        when v_roll < 0.50 then 3
        when v_roll < 0.85 then 5
        else 8
      end
    when 'medium' then
      case
        when v_roll < 0.40 then 8
        when v_roll < 0.80 then 12
        else 15
      end
    when 'hard' then
      case
        when v_roll < 0.40 then 15
        when v_roll < 0.80 then 20
        else 25
      end
    else 5
  end;
end;
$$;

create or replace function public._daily_quest_pick_id(
  p_difficulty text,
  p_user_id uuid,
  p_day date
)
returns text
language plpgsql
immutable
as $$
declare
  v_pool text[] := public._daily_quest_pool(p_difficulty);
  v_idx int;
begin
  if coalesce(array_length(v_pool, 1), 0) = 0 then
    return null;
  end if;

  v_idx := (
    abs(hashtext(p_user_id::text || '|' || p_day::text || '|' || p_difficulty))
    % array_length(v_pool, 1)
  ) + 1;

  return v_pool[v_idx];
end;
$$;

create or replace function public._daily_quest_hardcore_unlocked(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select coalesce(p.trophy_wins_normal, 0)
       + coalesce(p.trophy_wins_elite, 0)
       + coalesce(p.trophy_wins_unique, 0) >= 10
  from public.profiles p
  where p.id = p_user_id;
$$;

create or replace function public._daily_quest_is_ranked_room(p_room_type text)
returns boolean
language sql
immutable
as $$
  select lower(coalesce(p_room_type, '')) in (
    'normal', 'elite', 'unique', 'hardcore'
  );
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
      public._daily_quest_roll_reward(v_diff),
      0,
      public._daily_quest_target(v_quest_id)
    );
  end loop;
end;
$$;

create or replace function public._daily_quest_evaluate_row(
  p_row public.daily_quest_assignments,
  p_room_type text,
  p_placement int,
  p_eliminated boolean,
  p_peak_radius numeric,
  p_survival_seconds numeric,
  p_particles int,
  p_player_kills int,
  p_bot_kills int,
  p_shield_uses int,
  p_match_completed boolean,
  p_matches_today int,
  p_wins_today int,
  p_hardcore_unlocked boolean
)
returns table (
  new_progress int,
  newly_completed boolean
)
language plpgsql
immutable
as $$
declare
  v_room text := lower(coalesce(p_room_type, ''));
  v_ranked boolean := public._daily_quest_is_ranked_room(v_room);
  v_kills_total int := greatest(0, coalesce(p_player_kills, 0))
                     + greatest(0, coalesce(p_bot_kills, 0));
  v_prog int := coalesce(p_row.progress, 0);
  v_target int := greatest(1, coalesce(p_row.target, 1));
  v_done boolean := p_row.completed_at is not null;
begin
  if v_done then
    return query select v_prog, false;
    return;
  end if;

  case p_row.quest_id
    when 'K1', 'K10' then
      if p_match_completed then
        v_prog := 1;
      end if;
    when 'K2' then
      v_prog := greatest(v_prog, floor(coalesce(p_peak_radius, 0))::int);
    when 'K3' then
      v_prog := greatest(v_prog, floor(coalesce(p_peak_radius, 0))::int);
    when 'K4' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_particles, 0)));
    when 'K5' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_particles, 0)));
    when 'K6' then
      v_prog := greatest(v_prog, floor(coalesce(p_survival_seconds, 0))::int);
    when 'K7' then
      v_prog := greatest(v_prog, floor(coalesce(p_survival_seconds, 0))::int);
    when 'K8' then
      v_prog := greatest(v_prog, v_kills_total);
    when 'K9' then
      if p_match_completed and v_room = 'normal' then
        v_prog := 1;
      end if;
    when 'O1' then
      if v_ranked and not p_eliminated and coalesce(p_placement, 99) <= 10 then
        v_prog := 1;
      end if;
    when 'O2' then
      if v_ranked and not p_eliminated and coalesce(p_placement, 99) <= 5 then
        v_prog := 1;
      end if;
    when 'O3' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_player_kills, 0)));
    when 'O4' then
      v_prog := greatest(v_prog, floor(coalesce(p_peak_radius, 0))::int);
    when 'O5' then
      v_prog := greatest(v_prog, floor(coalesce(p_peak_radius, 0))::int);
    when 'O6' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_shield_uses, 0)));
    when 'O7' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_matches_today, 0)));
    when 'O8' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_particles, 0)));
    when 'O9' then
      if p_match_completed and v_room in ('elite', 'unique') then
        v_prog := 1;
      end if;
    when 'O10' then
      if v_room = 'normal'
         and not p_eliminated
         and coalesce(p_placement, 99) <= 3 then
        v_prog := 1;
      end if;
    when 'Z1' then
      if v_room in ('normal', 'elite', 'unique')
         and not p_eliminated
         and coalesce(p_placement, 99) <= 3 then
        v_prog := 1;
      end if;
    when 'Z2' then
      if v_ranked
         and not p_eliminated
         and coalesce(p_placement, 1) = 1 then
        v_prog := 1;
      end if;
    when 'Z3' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_player_kills, 0)));
    when 'Z4' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_player_kills, 0)));
    when 'Z5' then
      v_prog := greatest(v_prog, floor(coalesce(p_peak_radius, 0))::int);
    when 'Z6' then
      v_prog := greatest(v_prog, floor(coalesce(p_peak_radius, 0))::int);
    when 'Z7' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_matches_today, 0)));
    when 'Z8' then
      v_prog := greatest(v_prog, greatest(0, coalesce(p_wins_today, 0)));
    when 'Z9' then
      if v_room in ('elite', 'unique')
         and not p_eliminated
         and coalesce(p_placement, 1) = 1 then
        v_prog := 1;
      end if;
    when 'Z10' then
      if p_hardcore_unlocked then
        if p_match_completed and v_room = 'hardcore' then
          v_prog := 1;
        end if;
      elsif v_room in ('elite', 'unique')
            and not p_eliminated
            and coalesce(p_placement, 1) = 1 then
        v_prog := 1;
      end if;
    else
      null;
  end case;

  return query
  select
    v_prog,
    (v_prog >= v_target);
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: status (assigns today's quests if missing)
-- ---------------------------------------------------------------------------

create or replace function public.get_daily_quests_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
  v_reset timestamptz := ((v_day + 1)::timestamp at time zone 'utc');
  v_quests jsonb;
  v_claimable int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._daily_quest_ensure_assignments(v_uid, v_day);

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
  where a.user_id = v_uid
    and a.quest_day = v_day;

  select count(*)::int
  into v_claimable
  from public.daily_quest_assignments a
  where a.user_id = v_uid
    and a.quest_day = v_day
    and a.completed_at is not null
    and a.claimed_at is null;

  return jsonb_build_object(
    'quest_day', v_day,
    'next_reset_at', v_reset,
    'quests', v_quests,
    'claimable_count', coalesce(v_claimable, 0)
  );
end;
$$;

revoke all on function public.get_daily_quests_status() from public, anon;
grant execute on function public.get_daily_quests_status() to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: sync match progress
-- ---------------------------------------------------------------------------

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

    update public.daily_quest_assignments a
    set
      progress = v_eval.new_progress,
      completed_at = case
        when v_eval.newly_completed then timezone('utc', now())
        else a.completed_at
      end
    where a.id = r.id;
  end loop;

  return public.get_daily_quests_status();
end;
$$;

revoke all on function public.report_daily_quest_match(
  text, int, boolean, numeric, numeric, int, int, int, int, boolean
) from public, anon;
grant execute on function public.report_daily_quest_match(
  text, int, boolean, numeric, numeric, int, int, int, int, boolean
) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: claim completed quest reward
-- ---------------------------------------------------------------------------

create or replace function public.claim_daily_quest_reward(p_quest_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
  v_row public.daily_quest_assignments%rowtype;
  v_new_diamonds int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select *
  into v_row
  from public.daily_quest_assignments a
  where a.user_id = v_uid
    and a.quest_day = v_day
    and a.quest_id = p_quest_id
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_row.completed_at is null then
    return jsonb_build_object('ok', false, 'reason', 'not_completed');
  end if;

  if v_row.claimed_at is not null then
    return jsonb_build_object('ok', false, 'reason', 'already_claimed');
  end if;

  update public.daily_quest_assignments
  set claimed_at = timezone('utc', now())
  where id = v_row.id;

  perform public._allow_trusted_profile_write();

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_row.reward_diamonds),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  if v_new_diamonds is null then
    raise exception 'profile_missing';
  end if;

  return jsonb_build_object(
    'ok', true,
    'quest_id', v_row.quest_id,
    'awarded', v_row.reward_diamonds,
    'diamonds', v_new_diamonds
  );
end;
$$;

revoke all on function public.claim_daily_quest_reward(text) from public, anon;
grant execute on function public.claim_daily_quest_reward(text) to authenticated;

notify pgrst, 'reload schema';
